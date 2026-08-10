# OKAS HomeKit — KNX bridge architecture

KNX bus I/O was moved out of Node.js (`knx` npm library) into a standalone
**Python / xknx** process. The two processes talk to each other over the local
MQTT broker (Mosquitto) that already runs on the Debian host.

```
 iOS Home app ── HomeKit ──┐
                           │  (hap-nodejs)
                    ┌───────▼────────┐   okas/knx/cmd    ┌────────────────┐
   mobile app ──────►   Index.js     ├──────────────────►│  knx_bridge.py │──► KNX bus
   (mobile MQTT     │  (Node.js)     │◄──────────────────┤   (xknx, TCP    │◄── KNX bus
    API, unchanged) │                │   okas/knx/state   │   tunnelling)   │
                    └───────┬────────┘   okas/knx/conn    └────────────────┘
                            │  (KNX/knxBridge.js)
                       MQTT broker (localhost:1883)
```

## Gateway outage / IP-change recovery

When the gateway becomes unreachable (router reboot, IP change, eElectron
KNX Secure interface rebooting, etc.) the bridge MUST stay alive and retry
until the gateway returns. The implementation:

- `xknx`'s internal `auto_reconnect` loop is **disabled** — it traps the
  process in an infinite retry inside one xknx object and never lets our
  outer retry loop rebuild state. Outer-loop retries are the single source
  of truth.
- The outer loop in `KnxBridge.run()` catches every tunnel failure,
  publishes `okas/knx/conn={connected:false}` so the mobile app sees the
  outage immediately, rebuilds a fresh `XKNX` instance, and waits with
  exponential backoff capped at 120 s.
- `xknx.stop()` is bounded with `asyncio.wait_for(timeout=5.0)` so a stuck
  `DISCONNECT_RESPONSE` handshake (gateway gone mid-session) cannot wedge
  the loop.
- `Data/loadData.json` is **only read at startup**. Changing `gwIP` while
  the service is running has no effect — `systemctl restart OhKnxKnx.service`
  is required to pick up the new IP.

To switch the active gateway on the live board:

```bash
ssh root@okas-homekit.local
sed -i 's/"gwIP": "OLD.IP"/"gwIP": "NEW.IP"/' /home/OhKnx/Data/loadData.json
systemctl restart OhKnxKnx.service
journalctl -u OhKnxKnx.service -f
```

The bridge will connect immediately if the gateway is up, or fall into the
retry loop with "KNX connect failed (Tunnel connection could not be
established). Retrying in background …" and keep trying with backoff.

## Why

The Node `knx` library sent tunnelling telegrams with a fixed/foreign KNX
source address, which the eElectron KNX Secure IP interface silently dropped
(TunnelAck but no `L_Data.con`). xknx adopts the individual address the interface
assigns at connect time, so writes actually reach the bus. It defaults to **UDP
tunnelling (v1)**; set `knxConn: "tcp"` to use **TCP tunnelling v2** (ETS-style)
if the interface rejects UDP.

## Internal MQTT protocol (JS ↔ Python)

| Topic            | Direction   | Payload                                    |
|------------------|-------------|--------------------------------------------|
| `okas/knx/cmd`   | JS → Python | `{ ga, dpt, val, nm, dp }` — write to bus  |
| `okas/knx/state` | Python → JS | `{ ga, val }` — decoded bus feedback       |
| `okas/knx/conn`  | Python → JS | `{ connected }` — KNX link status (retained, LWT) |
| `okas/knx/sync`  | JS → Python | `{}` — re-read all status group addresses  |

`val` is a decoded primitive (`bool` / number / `{red,green,blue}`), so the Node
side never needs a KNX DPT decoder. DPTs come from `Data/loadData.json` (same
`GA` map both sides read).

## Files

- `KNX/knx_bridge.py` — Python xknx process (all bus I/O).
- `KNX/knxBridge.js` — Node MQTT client to the Python process (`knxCmd`, `isCon`).
- `KNX/actHdlr.js` — HomeKit/mobile actions → `knxCmd()` publishes commands.
- `KNX/repHdlr.js` — `applyKnxState(ga,val)` applies feedback to HomeKit.
- `initLoads.js` — builds `knxLod` (state + GA map) without KNX objects.
- Removed: `KNX/comHdlr.js`, `KNX/scanIF.js`, `KNX/Control.js`, `knx`/`knxultimate` deps.

## Configuration

`Data/loadData.json` entry `[0]` (project settings):

- `gwIP`, `gwPort` — KNX/IP interface address (required).
- `knxConn` *(optional)* — `udp` (default), `tcp`, `routing`, or `auto`.
- `knxAddr` *(optional)* — individual address to request for the tunnel.

Env overrides: `MQTT_HOST`, `MQTT_PORT`, `KNX_GATEWAY_IP`, `KNX_GATEWAY_PORT`,
`KNX_CONN`, `KNX_LOG`.

## Running

```bash
# Node service (HomeKit + mobile MQTT API)
node Index.js

# Python KNX bridge
pip install -r requirements.txt
python3 KNX/knx_bridge.py
```

On the Debian host, install both systemd units and enable them:

```bash
cp runOnce/HkBStartUp.service runOnce/OhKnxKnx.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now HkBStartUp.service OhKnxKnx.service
```

Start order does not matter — each side reconnects on its own, and the KNX link
status is republished (retained) whenever the Python bridge connects.
