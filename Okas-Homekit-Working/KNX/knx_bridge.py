#!/usr/bin/env python3
"""
OKAS HomeKit - KNX bridge (Python / xknx)

Replaces the old Node.js `knx` implementation. All KNX bus I/O now happens
here: the process connects to the KNX/IP interface with xknx and talks to the
Node.js side (Index.js / HomeKit) purely over the local MQTT broker.

Message flow:
    Node.js (HomeKit)  --[okas/knx/cmd]-->  Python  --> KNX bus     (commands)
    KNX bus  --> Python  --[okas/knx/state]-->  Node.js (HomeKit)   (feedback)
    Python   --[okas/knx/conn]--> Node.js                           (link status)

Why Python/xknx: the Node `knx` library sent tunnelling telegrams with a
fixed/foreign source individual address, which the eElectron KNX Secure IP
interface silently dropped (TunnelAck but no L_Data.con). xknx adopts the
individual address the interface assigns at connect time, so telegrams actually
reach the bus. Defaults to UDP tunnelling (v1); switch to TCP (v2, ETS-style)
via `knxConn: "tcp"` in loadData.json if the interface rejects UDP.
"""

import asyncio
import enum
import json
import logging
import os
import signal
import sys

import paho.mqtt.client as mqtt

from xknx import XKNX
from xknx.io import ConnectionConfig, ConnectionType
from xknx.io.connection import SecureConfig
from xknx.telegram import Telegram
from xknx.telegram.address import IndividualAddress
from xknx.telegram.apci import GroupValueResponse, GroupValueWrite
from xknx.tools import group_value_read, group_value_write
from xknx.dpt import DPTArray, DPTBase, DPTBinary

# ── Paths & MQTT configuration ──
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_FILE = os.path.join(BASE_DIR, "Data", "loadData.json")

MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_CLIENT_ID = "okas-knx-tunnel"

# Internal bridge topics (must match KNX/knxBridge.js)
TPC_CMD = "okas/knx/cmd"      # Node -> Python : { ga, dpt, val, nm?, dp? }
TPC_STATE = "okas/knx/state"  # Python -> Node : { ga, val }
TPC_CONN = "okas/knx/conn"    # Python -> Node : { connected } (retained)
TPC_SYNC = "okas/knx/sync"    # Node -> Python : {} -> re-read all status GAs

# GA keys carrying live feedback; these are the datapoints Python autoreads on connect.
STATUS_KEYS = {"Sta", "Bvi", "Clv", "Tuv", "Trm", "Fsv", "Tmv", "Mvi", "Pvi"}

# DPT map mirrors Data/iData.js `dptObj`; duplicated on purpose, Python stands alone.
DPT_OBJ = {
    "Swt": "1.001", "Sta": "1.001",
    "Dim": "3.007",
    "Bri": "5.001", "Bvi": "5.001",
    "Clc": "232.600", "Clv": "232.600",
    "Tuc": "7.600", "Tuv": "7.600",
    "Trm": "9.001", "Tsp": "9.001",
    "Fsc": "5.010", "Fsv": "5.010",
    "Thc": "1.100",
    "Tmc": "20.102", "Tmv": "20.102",
    "Scn": "17.001",
    "Mov": "1.008", "Mvi": "1.008",
    "Stp": "1.010",
    "Pos": "5.001", "Pvi": "5.001",
    "Tim": "10.001",
}

log = logging.getLogger("knx_bridge")


def norm_dpt(dpt):
    """Normalise a DPT string to the form xknx expects ('DPT1.001' -> '1.001')."""
    if not dpt:
        return None
    s = str(dpt).strip().upper()
    if s.startswith("DPT-"):
        s = s[4:]
    elif s.startswith("DPT"):
        s = s[3:]
    return s


def to_primitive(val, payload):
    """Convert an xknx-decoded value into a JSON-friendly primitive that mirrors
    what the old Node `knx` dptlib produced (bool / number / {red,green,blue})."""
    # RGB colour object -> plain dict (duck-typed to avoid version-specific import)
    if hasattr(val, "red") and hasattr(val, "green") and hasattr(val, "blue"):
        return {"red": int(val.red), "green": int(val.green), "blue": int(val.blue)}
    # Enums (Switch, HVACMode, UpDown, ...) -> underlying numeric/bool value.
    if isinstance(val, enum.Enum):
        ev = val.value
        if isinstance(ev, (bool, int, float)):
            return ev
        # Non-numeric enum (e.g. HVAC mode name) -> the raw KNX byte keeps numeric handlers sane.
        if isinstance(payload, DPTBinary):
            return int(payload.value)
        if isinstance(payload, DPTArray):
            raw = payload.value
            return int(raw[0]) if len(raw) == 1 else list(raw)
        return ev
    return val


class KnxBridge:
    STATE_STABLE_SECONDS = 3.0
    SYNC_COALESCE_SECONDS = 1.0

    def __init__(self, config):
        self.cfg = config
        self.loop = None
        self.xknx = None
        self.mqtt = None
        self.knx_connected = False
        self._last_state_change = 0.0
        self._stable_connected = False  # last value we actually published
        self._autoread_done_for_session = False  # one autoread per real reconnect
        self._sync_timer = None  # coalesce handle for incoming SYNC requests

        # Build GA -> DPT map (for decoding) and the list of status GAs to read.
        self.ga_dpt = {}          # "0/4/5" -> "1.001"
        self.autoread_gas = []    # status GAs to GroupValueRead on connect
        for load in config.get("loads", []):
            for key, ga in (load.get("GA") or {}).items():
                dpt = norm_dpt(DPT_OBJ.get(key))
                if not ga or not dpt:
                    continue
                self.ga_dpt[ga] = dpt
                if key in STATUS_KEYS and ga not in self.autoread_gas:
                    self.autoread_gas.append(ga)
        log.info("Mapped %d group addresses (%d status GAs to auto-read).",
                 len(self.ga_dpt), len(self.autoread_gas))

    # - MQTT ---
    def start_mqtt(self):
        self.mqtt = mqtt.Client(client_id=MQTT_CLIENT_ID, clean_session=True)
        # Retained 'offline' link status; overwritten once KNX connects.
        self.mqtt.will_set(TPC_CONN, json.dumps({"connected": False}), qos=1, retain=True)
        self.mqtt.on_connect = self._on_mqtt_connect
        self.mqtt.on_message = self._on_mqtt_message
        self.mqtt.reconnect_delay_set(min_delay=1, max_delay=10)
        log.info("MQTT: connecting to %s:%d ...", MQTT_HOST, MQTT_PORT)
        self.mqtt.connect_async(MQTT_HOST, MQTT_PORT, keepalive=30)
        self.mqtt.loop_start()

    def _on_mqtt_connect(self, client, userdata, flags, reason_code):
        if reason_code != 0:
            log.warning("MQTT: connect failed (%s)", reason_code)
            return
        log.info("MQTT: connected.")
        client.subscribe([(TPC_CMD, 1), (TPC_SYNC, 1)])
        # Re-announce current KNX link status on every (re)connect.
        self._publish_conn(self.knx_connected)

    def _on_mqtt_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode("utf-8")) if msg.payload else {}
        except Exception as e:  # noqa: BLE001
            log.error("MQTT: bad JSON on %s - %s", msg.topic, e)
            return
        if msg.topic == TPC_CMD:
            self._handle_cmd(payload)
        elif msg.topic == TPC_SYNC:
            self._request_sync()

    def _publish_conn(self, connected):
        if self.mqtt:
            self.mqtt.publish(TPC_CONN, json.dumps({"connected": bool(connected)}),
                              qos=1, retain=True)

    def _publish_state(self, ga, val):
        if self.mqtt:
            self.mqtt.publish(TPC_STATE, json.dumps({"ga": ga, "val": val}), qos=1)

    # -- Commands ---
    def _handle_cmd(self, payload):
        ga = payload.get("ga")
        val = payload.get("val")
        dpt = norm_dpt(payload.get("dpt")) or self.ga_dpt.get(ga)
        if not ga or dpt is None or val is None:
            log.error("MQTT: invalid command payload: %s", payload)
            return
        label = payload.get("nm") or ga
        if not self.knx_connected:
            log.warning("KNX write to %s skipped - interface disconnected.", label)
            return
        if self.loop:
            self.loop.call_soon_threadsafe(self._do_write, ga, val, dpt, label)

    # Clamp to DPT ranges; the app drags sliders hard and the bus (and the logs) hate 999.
    DPT_RANGES = {
        "1.001": (0, 1),    # boolean switch
        "1.008": (0, 1),    # move
        "1.010": (0, 1),    # stop
        "1.100": (0, 1),    # heat/cool
        "3.007": (0, 100),  # dimming (relative)
        "5.001": (0, 100),  # scaling / brightness / position
        "5.010": (0, 255),  # 1-byte unsigned (fan speed)
        "7.600": (0, 65535),  # color temperature (Kelvin)
        "9.001": (0, 40),   # temperature °C (extended range, clamp to sane HVAC)
        "17.001": (1, 64),  # scene number (1-based per xknx DPTSceneNumber)
        "20.102": (0, 3),   # HVAC mode (raw enum)
        "232.600": (0, 255),  # RGB — clamped per channel below
    }

    @staticmethod
    def _clamp_dpt(dpt, val):
        """Clamp a value to the DPT's legal range. Returns the clamped value
        (or the original when the DPT is unknown / unclamped)."""
        try:
            num = float(val)
        except (TypeError, ValueError):
            return val  # strings / dicts pass through untouched
        rng = KnxBridge.DPT_RANGES.get(dpt)
        if not rng:
            return val
        lo, hi = rng
        return int(max(lo, min(hi, round(num))))

    def _do_write(self, ga, val, dpt, label):
        try:
            # Clamp out-of-range numerics per DPT (see DPT_RANGES).
            if isinstance(val, dict):
                # RGB dict: clamp each channel to 0-255.
                val = {
                    k: int(max(0, min(255, round(float(v)))))
                    if k in ("red", "green", "blue") else v
                    for k, v in val.items()
                }
            else:
                val = self._clamp_dpt(dpt, val)
            group_value_write(self.xknx, ga, val, value_type=dpt)
            log.info("KNX write -> %s (%s) = %s [DPT %s]", ga, label, val, dpt)
        except Exception as e:  # noqa: BLE001
            log.error("KNX write to %s failed: %s", ga, e)

    def _schedule_autoread(self):
        self._sync_timer = None
        if not self.knx_connected:
            return
        for ga in self.autoread_gas:
            try:
                group_value_read(self.xknx, ga)
            except Exception as e:  # noqa: BLE001
                log.error("KNX read request for %s failed: %s", ga, e)
        if self.autoread_gas:
            log.info("KNX: requested read of %d status GAs.", len(self.autoread_gas))

    def _request_sync(self):
        if not self.loop:
            return
        if not self.knx_connected:
            log.debug("MQTT: sync ignored - KNX interface disconnected.")
            return
        self.loop.call_soon_threadsafe(self._schedule_sync_timer)

    def _schedule_sync_timer(self):
        if self._sync_timer is not None:
            try:
                self._sync_timer.cancel()
            except Exception:  # noqa: BLE001
                pass
        self._sync_timer = self.loop.call_later(self.SYNC_COALESCE_SECONDS,
                                                self._schedule_autoread)
        log.info("MQTT: sync requested -> re-reading status GAs (coalesced).")

    # ── xknx callbacks ──
    # xknx calls these SYNCHRONOUSLY — an `async def` here silently does nothing (no feedback, isCon stays false).
    def _on_telegram(self, telegram):
        payload = telegram.payload
        if not isinstance(payload, (GroupValueWrite, GroupValueResponse)):
            return
        ga = str(telegram.destination_address)
        dpt = self.ga_dpt.get(ga)
        if not dpt:
            return  # unknown / unconfigured group address
        try:
            transcoder = DPTBase.parse_transcoder(dpt)
            decoded = transcoder.from_knx(payload.value)
            val = to_primitive(decoded, payload.value)
        except Exception as e:  # noqa: BLE001
            log.error("KNX decode failed for %s [DPT %s]: %s", ga, dpt, e)
            return
        self._publish_state(ga, val)
        log.debug("KNX state <- %s = %s", ga, val)

    def _on_conn_state(self, state):
        connected = str(getattr(state, "name", state)).upper() == "CONNECTED"
        now = asyncio.get_event_loop().time() if self.loop else 0.0

        # Debounce flapping tunnels; forward only first-or-STATE_STABLE_SECONDS-old changes.
        if connected == self._stable_connected:
            # Mirror internal flag without re-publishing.
            self.knx_connected = connected
            return
        if connected and self._stable_connected and (now - self._last_state_change) < self.STATE_STABLE_SECONDS:
            log.debug("KNX interface CONNECTED pulse ignored (flap window).")
            self.knx_connected = connected
            return

        self.knx_connected = connected
        self._stable_connected = connected
        self._last_state_change = now
        log.info("KNX interface %s.", "connected" if connected else "disconnected")
        self._publish_conn(connected)
        if connected:
            # One autoread per real reconnect — skip subsequent pulses.
            if not self._autoread_done_for_session and self.loop:
                self._autoread_done_for_session = True
                # Let the tunnel settle, then pull current states; interfaces wake up slowly.
                self.loop.call_later(5, self._schedule_autoread)
        else:
            # Real disconnect — arm the next reconnect to issue another read.
            self._autoread_done_for_session = False

    # ------------------------------------------------------------------ run ---
    async def run(self):
        self.loop = asyncio.get_running_loop()
        self.start_mqtt()

        conn = self.cfg["connection"]
        connection_config = ConnectionConfig(
            connection_type=conn["type"],
            gateway_ip=conn.get("gateway_ip"),
            gateway_port=conn.get("gateway_port", 3671),
            individual_address=conn.get("individual_address"),
            auto_reconnect=False,
            auto_reconnect_wait=3,
            secure_config=conn.get("secure_config"),
        )

        self.xknx = XKNX(
            connection_config=connection_config,
            telegram_received_cb=self._on_telegram,
            connection_state_changed_cb=self._on_conn_state,
        )

        stop = asyncio.Event()

        def _request_stop(*_):
            log.info("Shutdown signal received.")
            stop.set()

        try:
            self.loop.add_signal_handler(signal.SIGINT, _request_stop)
            self.loop.add_signal_handler(signal.SIGTERM, _request_stop)
        except NotImplementedError:
            # Windows: signal handlers on the loop are unavailable; rely on KeyboardInterrupt.
            pass

        log.info("Starting KNX bridge (type=%s, gateway=%s:%s) ...",
                 conn["type"].name, conn.get("gateway_ip"), conn.get("gateway_port"))

        # Retry with exponential backoff instead of crash-looping systemd; give up only on SIGINT/SIGTERM.
        retry_delay = 2  # seconds
        max_retry = 120  # 2 min cap
        first_attempt = True
        while not stop.is_set():
            try:
                # Fresh connection; the next real CONNECTED triggers the autoread pass.
                self._stable_connected = False
                self._last_state_change = 0.0
                self._autoread_done_for_session = False
                async with self.xknx:
                    retry_delay = 2  # reset on Success
                    await stop.wait()
                break  # normal exit
            except asyncio.CancelledError:
                break
            except Exception as exc:  # noqa: BLE001
                if first_attempt:
                    log.warning("KNX connect failed (%s). Retrying in background ...", exc)
                    first_attempt = False
                else:
                    log.debug("KNX connect still failing (%s). Next retry in %ds.", exc, retry_delay)
                self._publish_conn(False)
                # Tear down cleanly and bounded; a stuck DISCONNECT handshake mustn't wedge the retry loop.
                try:
                    await asyncio.wait_for(self.xknx.stop(), timeout=5.0)
                except asyncio.TimeoutError:
                    log.warning("xknx.stop() timed out; discarding tunnel state.")
                except Exception:  # noqa: BLE001
                    pass
                self.xknx = XKNX(
                    connection_config=connection_config,
                    telegram_received_cb=self._on_telegram,
                    connection_state_changed_cb=self._on_conn_state,
                )
                try:
                    await asyncio.wait_for(stop.wait(), timeout=retry_delay)
                except asyncio.TimeoutError:
                    pass
                retry_delay = min(retry_delay * 2, max_retry)

        log.info("KNX bridge stopping - notifying Node.js.")
        self._publish_conn(False)
        if self.mqtt:
            self.mqtt.loop_stop()
            self.mqtt.disconnect()


# ── Config loading ──
_CONN_TYPES = {
    "tcp": ConnectionType.TUNNELING_TCP,
    "udp": ConnectionType.TUNNELING,
    "routing": ConnectionType.ROUTING,
    "auto": ConnectionType.AUTOMATIC,
}


def load_config():
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list) or len(data) < 1:
        raise ValueError("loadData.json is empty or malformed.")

    project = data[0] or {}
    loads = [x for x in data[1:] if isinstance(x, dict) and x.get("GA")]

    # UDP tunnelling v1 by default; xknx adopts the address the interface assigns (v1 just works), 'tcp' is the escape hatch.
    conn_kind = str(os.environ.get("KNX_CONN", project.get("knxConn", "udp"))).lower()
    conn_type = _CONN_TYPES.get(conn_kind, ConnectionType.TUNNELING)

    ia = project.get("knxAddr")  # optional individual address to request for the tunnel
    connection = {
        "type": conn_type,
        "gateway_ip": os.environ.get("KNX_GATEWAY_IP", project.get("gwIP")),
        "gateway_port": int(os.environ.get("KNX_GATEWAY_PORT", project.get("gwPort") or 3671)),
        "individual_address": IndividualAddress(ia) if ia else None,
    }

    # ── KNX IP Secure ──
    # The eElectron enforces Secure tunnelling; credentials come from loadData.json or env.
    secure = None
    device_auth = os.environ.get(
        "KNX_DEVICE_AUTH", project.get("knxDeviceAuth")
    )
    user_pw = os.environ.get("KNX_USER_PASSWORD", project.get("knxUserPw"))
    user_id = int(os.environ.get("KNX_USER_ID", project.get("knxUserId") or 0))
    if device_auth:
        secure = SecureConfig(
            device_authentication_password=device_auth,
            user_password=user_pw,
            user_id=user_id,
        )
    connection["secure_config"] = secure

    return {"project": project, "loads": loads, "connection": connection}


def main():
    logging.basicConfig(
        level=os.environ.get("KNX_LOG", "INFO").upper(),
        format="[%(levelname)s] %(asctime)s knx_bridge: %(message)s",
        datefmt="%d.%b.%Y %H:%M:%S",
    )
    try:
        config = load_config()
    except Exception as e:  # noqa: BLE001
        log.error("Failed to load config: %s", e)
        sys.exit(1)

    bridge = KnxBridge(config)
    try:
        asyncio.run(bridge.run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
