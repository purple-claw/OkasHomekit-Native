#!/usr/bin/env python3
"""
OKAS MQTT Tester — GUI testing tool for the OKAS HomeKit system.
"""

import json
import os
import random
import socket
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
from datetime import datetime

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("Missing paho-mqtt. Install: pip3 install paho-mqtt")
    raise SystemExit(1)

# ── Config ───────────────────────────────────────────────────────────────────
DEFAULT_HOST = "okas-homekit.local"
DEFAULT_PORT = 1883
AUTH_PORT = 1884
AUTH_USER = "okasapi"
AUTH_PASS = ""
CLIENT_ID = "okas-tester-" + os.urandom(4).hex()

TPC_LOADS_GET = "loads/getLoads"
TPC_LOADS_SET = "loads/setLoads"
TPC_CMD_SEND = "command/sndCmd"
TPC_CMD_ACK = "command/cmdAck"
TPC_MOB_ACK = "status/mobAck"
TPC_STATUS_TOPIC = "status"

LOAD_TYPES = {
    "swt": "Switch",
    "dim": "Dimmer",
    "rgb": "RGB",
    "tun": "Tunable White",
    "hvc": "HVAC",
    "fan": "Fan",
    "cur": "Curtain",
    "scn": "Scene",
}


class MqttTesterGui:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("OKAS MQTT Tester")
        self.root.geometry("1280x800")
        self.root.minsize(960, 600)

        self.local_client = None
        self.auth_client = None
        self.local_connected = False
        self.auth_connected = False
        self.loads = []
        self.subscriptions = set()
        self._stop = threading.Event()

        self._build_ui()
        self.root.after(500, self._auto_connect)

    def _build_ui(self):
        style = ttk.Style()
        style.theme_use("clam")
        bg = "#1e1e2e"
        fg = "#cdd6f4"
        entry_bg = "#313244"
        accent = "#89b4fa"
        for name in ("TLabel", "TFrame", "TLabelframe", "TLabelframe.Label", "TButton"):
            style.configure(name, background=bg, foreground=fg)
        style.configure("TLabelframe", bordercolor="#45475a", borderwidth=1)
        style.configure("TButton", padding=(8, 2), background="#45475a", foreground=fg, borderwidth=0)
        style.map("TButton", background=[("active", "#585b70")])
        style.configure("Accent.TButton", background=accent, foreground="#1e1e2e")
        style.map("Accent.TButton", background=[("active", "#74c7ec")])
        self.root.configure(bg=bg)

        main_pane = tk.PanedWindow(self.root, orient=tk.HORIZONTAL, bg=bg, sashwidth=4, sashrelief=tk.FLAT)
        main_pane.pack(fill=tk.BOTH, expand=True, padx=6, pady=6)

        # ── LEFT PANEL ──
        left = ttk.Frame(main_pane)
        main_pane.add(left, width=400, minsize=320)

        # Connection
        conn_frame = ttk.LabelFrame(left, text="Connection", padding=8)
        conn_frame.pack(fill=tk.X, pady=(0, 6))

        row0 = ttk.Frame(conn_frame)
        row0.pack(fill=tk.X)
        ttk.Label(row0, text="Host:").pack(side=tk.LEFT)
        self.host_var = tk.StringVar(value=DEFAULT_HOST)
        ttk.Entry(row0, textvariable=self.host_var, width=20, background=entry_bg, foreground=fg).pack(side=tk.LEFT, padx=4)

        ttk.Label(row0, text="Auth Pass:").pack(side=tk.LEFT, padx=(12, 0))
        self.auth_var = tk.StringVar(value=AUTH_PASS)
        ttk.Entry(row0, textvariable=self.auth_var, width=14, show="*", background=entry_bg, foreground=fg).pack(side=tk.LEFT, padx=4)

        row1 = ttk.Frame(conn_frame)
        row1.pack(fill=tk.X, pady=(4, 0))
        self.conn_btn = ttk.Button(row1, text="🔌 Connect", command=self._toggle_connect, style="Accent.TButton")
        self.conn_btn.pack(side=tk.LEFT)
        self.conn_label = ttk.Label(row1, text="Disconnected", foreground="#f38ba8")
        self.conn_label.pack(side=tk.LEFT, padx=8)
        self.auth_label = ttk.Label(row1, text="", foreground="#f38ba8")
        self.auth_label.pack(side=tk.LEFT, padx=4)

        # Loads
        loads_frame = ttk.LabelFrame(left, text="Loads (double-click to test)", padding=8)
        loads_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 6))

        loads_btn_row = ttk.Frame(loads_frame)
        loads_btn_row.pack(fill=tk.X, pady=(0, 4))
        ttk.Button(loads_btn_row, text="🔄 Refresh Loads", command=self._request_loads).pack(side=tk.LEFT, padx=2)
        ttk.Button(loads_btn_row, text="🧹 Clear Retained", command=self._clear_retained).pack(side=tk.LEFT, padx=2)

        self.loads_tree = ttk.Treeview(loads_frame, columns=("id", "name", "type", "state"), show="headings",
                                       height=10, selectmode="browse")
        self.loads_tree.heading("id", text="ID")
        self.loads_tree.heading("name", text="Name")
        self.loads_tree.heading("type", text="Type")
        self.loads_tree.heading("state", text="State")
        self.loads_tree.column("id", width=30, anchor=tk.CENTER)
        self.loads_tree.column("name", width=120)
        self.loads_tree.column("type", width=80)
        self.loads_tree.column("state", width=80, anchor=tk.CENTER)
        self.loads_tree.bind("<Double-1>", self._on_load_double_click)
        loads_scroll = ttk.Scrollbar(loads_frame, orient=tk.VERTICAL, command=self.loads_tree.yview)
        self.loads_tree.configure(yscrollcommand=loads_scroll.set)
        self.loads_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        loads_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        # Subscriptions
        sub_frame = ttk.LabelFrame(left, text="Subscriptions", padding=8)
        sub_frame.pack(fill=tk.X, pady=(0, 6))

        row_s = ttk.Frame(sub_frame)
        row_s.pack(fill=tk.X)
        self.sub_var = tk.StringVar(value="#")
        ttk.Entry(row_s, textvariable=self.sub_var, background=entry_bg, foreground=fg).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(row_s, text="➕ Subscribe", command=self._subscribe_topic).pack(side=tk.LEFT)
        ttk.Button(row_s, text="✖ Unsub", command=self._unsubscribe_topic).pack(side=tk.LEFT, padx=2)

        row_s2 = ttk.Frame(sub_frame)
        row_s2.pack(fill=tk.X, pady=(2, 0))
        ttk.Button(row_s2, text="📋 Loads Topics", command=self._sub_loads).pack(side=tk.LEFT, padx=1)
        ttk.Button(row_s2, text="📋 Status Topics", command=self._sub_status).pack(side=tk.LEFT, padx=1)
        ttk.Button(row_s2, text="📋 Ack Topics", command=self._sub_ack).pack(side=tk.LEFT, padx=1)

        # ── RIGHT PANEL ──
        right = ttk.Frame(main_pane)
        main_pane.add(right, width=600, minsize=400)

        # Send Command
        cmd_frame = ttk.LabelFrame(right, text="Send Command", padding=8)
        cmd_frame.pack(fill=tk.X, pady=(0, 6))

        cmd_r1 = ttk.Frame(cmd_frame)
        cmd_r1.pack(fill=tk.X)
        ttk.Label(cmd_r1, text="Load ID:").pack(side=tk.LEFT)
        self.cmd_ldid = tk.StringVar(value="1")
        ttk.Spinbox(cmd_r1, from_=1, to=99, textvariable=self.cmd_ldid, width=5, background=entry_bg, foreground=fg).pack(side=tk.LEFT, padx=4)
        ttk.Label(cmd_r1, text="Type:").pack(side=tk.LEFT, padx=(8, 0))
        self.cmd_type = tk.StringVar(value="swt")
        type_combo = ttk.Combobox(cmd_r1, textvariable=self.cmd_type, values=list(LOAD_TYPES.keys()), width=8, background=entry_bg, foreground=fg)
        type_combo.pack(side=tk.LEFT, padx=4)
        ttk.Label(cmd_r1, text="Broker:").pack(side=tk.LEFT, padx=(8, 0))
        self.cmd_broker = tk.StringVar(value="local")
        ttk.Combobox(cmd_r1, textvariable=self.cmd_broker, values=("local", "auth"), width=8, background=entry_bg, foreground=fg).pack(side=tk.LEFT, padx=4)

        cmd_r2 = ttk.Frame(cmd_frame)
        cmd_r2.pack(fill=tk.X, pady=(4, 0))
        self.cmd_params = tk.StringVar(value='{"swt":true}')
        ttk.Label(cmd_r2, text="Params (JSON):").pack(side=tk.LEFT)
        ttk.Entry(cmd_r2, textvariable=self.cmd_params, background=entry_bg, foreground=fg).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Button(cmd_r2, text="📤 Send", command=self._send_command, style="Accent.TButton").pack(side=tk.LEFT)

        # Quick buttons
        btn_r = ttk.Frame(cmd_frame)
        btn_r.pack(fill=tk.X, pady=(2, 0))
        for label, params in [
            ("ON", '{"swt":true}'),
            ("OFF", '{"swt":false}'),
            ("Bri 50", '{"bri":50}'),
            ("Bri 100", '{"bri":100}'),
            ("Hue 120", '{"hue":120}'),
            ("cTp 4000", '{"cTp":4000}'),
            ("Pos 75", '{"pos":75}'),
            ("Scene 1", '{"scn":1}'),
        ]:
            ttk.Button(btn_r, text=label, command=lambda p=params: self.cmd_params.set(p), width=10).pack(side=tk.LEFT, padx=1)

        # Command Cycle
        cycle_frame = ttk.LabelFrame(right, text="Full Command Cycle", padding=8)
        cycle_frame.pack(fill=tk.X, pady=(0, 6))

        ttk.Label(cycle_frame, text="Publishes command + subscribes ack/status topics:").pack(anchor=tk.W)
        cycle_r = ttk.Frame(cycle_frame)
        cycle_r.pack(fill=tk.X, pady=(2, 0))
        self.cycle_ldid = tk.StringVar(value="1")
        self.cycle_type = tk.StringVar(value="swt")
        self.cycle_params = tk.StringVar(value='{"swt":true}')
        ttk.Label(cycle_r, text="ID:").pack(side=tk.LEFT)
        ttk.Spinbox(cycle_r, from_=1, to=99, textvariable=self.cycle_ldid, width=4, background=entry_bg, foreground=fg).pack(side=tk.LEFT, padx=2)
        ttk.Label(cycle_r, text="Type:").pack(side=tk.LEFT)
        ttk.Combobox(cycle_r, textvariable=self.cycle_type, values=list(LOAD_TYPES.keys()), width=6, background=entry_bg, foreground=fg).pack(side=tk.LEFT, padx=2)
        ttk.Entry(cycle_r, textvariable=self.cycle_params, background=entry_bg, foreground=fg, width=24).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=2)
        ttk.Button(cycle_r, text="▶ Run Cycle", command=self._run_cycle, style="Accent.TButton").pack(side=tk.LEFT, padx=2)

        # MQTT Monitor
        monitor_frame = ttk.LabelFrame(right, text="MQTT Monitor", padding=8)
        monitor_frame.pack(fill=tk.BOTH, expand=True)

        mon_btn_row = ttk.Frame(monitor_frame)
        mon_btn_row.pack(fill=tk.X, pady=(0, 4))
        ttk.Button(mon_btn_row, text="🧹 Clear", command=self._clear_monitor).pack(side=tk.LEFT, padx=2)
        ttk.Button(mon_btn_row, text="📋 Copy All", command=self._copy_monitor).pack(side=tk.LEFT, padx=2)
        self.pause_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(mon_btn_row, text="Pause", variable=self.pause_var).pack(side=tk.LEFT, padx=12)
        self.filter_var = tk.StringVar(value="")
        ttk.Label(mon_btn_row, text="Filter:").pack(side=tk.LEFT, padx=(8, 0))
        ttk.Entry(mon_btn_row, textvariable=self.filter_var, background=entry_bg, foreground=fg, width=20).pack(side=tk.LEFT, padx=2)
        ttk.Button(mon_btn_row, text="⚡ Rapid Fire 10×", command=self._rapid_fire).pack(side=tk.RIGHT, padx=2)

        self.monitor_text = scrolledtext.ScrolledText(
            monitor_frame, state=tk.DISABLED, bg="#11111b", fg="#cdd6f4",
            insertbackground="#cdd6f4", font=("Consolas", 10), wrap=tk.WORD,
            relief=tk.FLAT, borderwidth=0
        )
        self.monitor_text.pack(fill=tk.BOTH, expand=True)

        self.status_var = tk.StringVar(value="Ready — connect to start")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief=tk.FLAT, anchor=tk.W, padding=(8, 2))
        status_bar.pack(fill=tk.X, side=tk.BOTTOM)

    # ── MQTT ───────────────────────────────────────────────────────────────────
    def _auto_connect(self):
        host = self.host_var.get().strip()
        if host:
            self._do_connect(host)

    def _toggle_connect(self):
        if self.local_connected:
            self._do_disconnect()
        else:
            host = self.host_var.get().strip()
            if not host:
                messagebox.showerror("Error", "Enter a host address")
                return
            self._do_connect(host)

    def _do_connect(self, host):
        self._stop.clear()

        self.local_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=CLIENT_ID, clean_session=True)
        self.local_client.will_set("okas/tester/status", json.dumps({"online": False}), qos=1, retain=True)
        self.local_client.on_connect = self._on_local_connect
        self.local_client.on_message = self._on_message
        self.local_client.on_disconnect = self._on_local_disconnect
        self.local_client.reconnect_delay_set(min_delay=1, max_delay=10)
        try:
            self.local_client.connect_async(host, DEFAULT_PORT, keepalive=30)
            self.local_client.loop_start()
            self.status_var.set(f"Connecting to {host}:{DEFAULT_PORT}...")
        except Exception as e:
            messagebox.showerror("Connection Error", str(e))
            return

        self.auth_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=CLIENT_ID + "-auth", clean_session=True)
        self.auth_client.on_connect = self._on_auth_connect
        self.auth_client.on_message = self._on_message
        self.auth_client.on_disconnect = self._on_auth_disconnect
        self.auth_client.reconnect_delay_set(min_delay=1, max_delay=10)
        auth_pass = self.auth_var.get().strip()
        if auth_pass:
            self.auth_client.username_pw_set(AUTH_USER, auth_pass)
        try:
            self.auth_client.connect_async(host, AUTH_PORT, keepalive=30)
            self.auth_client.loop_start()
        except Exception:
            self.auth_label.config(text="Auth broker unreachable", foreground="#f38ba8")

    def _do_disconnect(self):
        self._stop.set()
        if self.local_client:
            self.local_client.loop_stop()
            self.local_client.disconnect()
        if self.auth_client:
            self.auth_client.loop_stop()
            self.auth_client.disconnect()
        self.local_connected = False
        self.auth_connected = False
        self.conn_btn.config(text="🔌 Connect")
        self.conn_label.config(text="Disconnected", foreground="#f38ba8")
        self.auth_label.config(text="", foreground="#f38ba8")
        self.status_var.set("Disconnected")

    def _on_local_connect(self, client, userdata, flags, reason_code, properties=None):
        if reason_code == 0:
            self.local_connected = True
            self.conn_label.config(text="Local ✓", foreground="#a6e3a1")
            self.conn_btn.config(text="🔌 Disconnect")
            self.status_var.set(f"Connected to {self.host_var.get()}:{DEFAULT_PORT}")
            self._log_monitor("SYSTEM", f"Connected to local broker ({self.host_var.get()}:{DEFAULT_PORT})")
            self._do_subscribe("#")
            self._request_loads()
        else:
            self.conn_label.config(text=f"Failed ({reason_code})", foreground="#f38ba8")

    def _on_local_disconnect(self, client, userdata, flags, reason_code, properties=None):
        self.local_connected = False
        self.conn_label.config(text="Disconnected", foreground="#f38ba8")
        self.conn_btn.config(text="🔌 Connect")
        self._log_monitor("SYSTEM", "Disconnected from local broker")

    def _on_auth_connect(self, client, userdata, flags, reason_code, properties=None):
        if reason_code == 0:
            self.auth_connected = True
            self.auth_label.config(text="Auth ✓", foreground="#a6e3a1")
            self._log_monitor("SYSTEM", f"Connected to auth broker ({self.host_var.get()}:{AUTH_PORT})")
            self._do_auth_subscribe("#")
        else:
            self.auth_label.config(text=f"Auth fail ({reason_code})", foreground="#f38ba8")

    def _on_auth_disconnect(self, client, userdata, flags, reason_code, properties=None):
        self.auth_connected = False
        self.auth_label.config(text="Auth disconnected", foreground="#f38ba8")

    # ── Subscribe / Publish ──────────────────────────────────────────────────
    def _do_subscribe(self, topic):
        if self.local_client and self.local_connected:
            self.local_client.subscribe(topic, qos=1)
            self.subscriptions.add(topic)
            self._log_monitor("SUB", f"Subscribed to '{topic}' (local)")

    def _do_auth_subscribe(self, topic):
        if self.auth_client and self.auth_connected:
            self.auth_client.subscribe(topic, qos=1)
            self._log_monitor("SUB", f"Subscribed to '{topic}' (auth)")

    def _do_publish(self, topic, payload, broker="local"):
        payload_str = json.dumps(payload) if isinstance(payload, dict) else str(payload)
        if broker == "local" and self.local_client and self.local_connected:
            self.local_client.publish(topic, payload_str, qos=1)
            self._log_monitor("PUB", f"[local] {topic} {payload_str}")
        elif broker == "auth" and self.auth_client and self.auth_connected:
            self.auth_client.publish(topic, payload_str, qos=1)
            self._log_monitor("PUB", f"[auth]  {topic} {payload_str}")
        else:
            self._log_monitor("ERR", f"Broker '{broker}' not connected")

    def _subscribe_topic(self):
        topic = self.sub_var.get().strip()
        if topic:
            self._do_subscribe(topic)
            if self.auth_connected:
                self._do_auth_subscribe(topic)

    def _unsubscribe_topic(self):
        topic = self.sub_var.get().strip()
        if topic and self.local_client and self.local_connected:
            self.local_client.unsubscribe(topic)
            self.subscriptions.discard(topic)
            self._log_monitor("UNSUB", f"Unsubscribed from '{topic}'")

    def _sub_loads(self):
        for t in (TPC_LOADS_GET, TPC_LOADS_SET):
            self._do_subscribe(t)

    def _sub_status(self):
        self._do_subscribe(TPC_STATUS_TOPIC + "/+")

    def _sub_ack(self):
        for t in (TPC_CMD_ACK, TPC_MOB_ACK):
            self._do_subscribe(t)

    # ── Commands ──────────────────────────────────────────────────────────────
    def _send_command(self):
        try:
            ld_id = int(self.cmd_ldid.get())
            typ = self.cmd_type.get()
            params = json.loads(self.cmd_params.get())
            broker = self.cmd_broker.get()
        except (ValueError, json.JSONDecodeError) as e:
            messagebox.showerror("Invalid input", str(e))
            return
        payload = {"ldId": ld_id, "typ": typ, "cmd": params}
        self._do_publish(TPC_CMD_SEND, payload, broker)

    def _run_cycle(self):
        try:
            ld_id = int(self.cycle_ldid.get())
            typ = self.cycle_type.get()
            params = json.loads(self.cycle_params.get())
        except (ValueError, json.JSONDecodeError) as e:
            messagebox.showerror("Invalid input", str(e))
            return

        self._do_subscribe(TPC_CMD_ACK)
        self._do_subscribe(f"{TPC_STATUS_TOPIC}/{ld_id}")

        payload = {"ldId": ld_id, "typ": typ, "cmd": params}
        self._do_publish(TPC_CMD_SEND, payload)
        self._log_monitor("CYCLE", f"Step 1: Sent command → {json.dumps(payload)}")
        self._log_monitor("CYCLE", f"  Expect cmdAck (received) → cmdAck (executed) → status/{ld_id}")

    def _rapid_fire(self):
        try:
            ld_id = int(self.cmd_ldid.get())
        except ValueError:
            ld_id = 1
        self._log_monitor("STRESS", "Sending 10 rapid commands...")
        for i in range(10):
            on = (i % 2 == 0)
            payload = {"ldId": ld_id, "typ": "swt", "cmd": {"swt": on}}
            self._do_publish(TPC_CMD_SEND, payload)
            time.sleep(0.05)

    def _request_loads(self):
        self._do_publish(TPC_LOADS_GET, "{}")

    def _clear_retained(self):
        topics = [TPC_LOADS_SET, "command/recvCmd", "status/sndStatus", TPC_MOB_ACK]
        for i in range(1, 9):
            topics.append(f"{TPC_STATUS_TOPIC}/{i}")
        for t in topics:
            if self.local_client and self.local_connected:
                self.local_client.publish(t, None, qos=1, retain=True)
        self._log_monitor("SYS", "Cleared retained messages")

    def _on_load_double_click(self, event):
        sel = self.loads_tree.selection()
        if not sel:
            return
        item = self.loads_tree.item(sel[0])
        ld_id = item["values"][0]
        typ = item["values"][2]
        default_params = {
            "swt": '{"swt":true}',
            "dim": '{"bri":50}',
            "rgb": '{"hue":120,"sat":80,"bri":50}',
            "tun": '{"cTp":3500,"bri":80}',
            "hvc": '{"spt":23}',
            "fan": '{"fSp":3}',
            "cur": '{"pos":75}',
            "scn": '{"scn":1}',
        }
        self.cmd_ldid.set(str(ld_id))
        self.cmd_type.set(typ)
        self.cmd_params.set(default_params.get(typ, '{}'))
        self._log_monitor("GUI", f"Loaded test command for ID={ld_id} type={typ}")

    # ── Message Handler ─────────────────────────────────────────────────────
    def _on_message(self, client, userdata, msg):
        try:
            payload_str = msg.payload.decode("utf-8") if msg.payload else "(null)"
        except Exception:
            payload_str = repr(msg.payload)

        try:
            parsed = json.loads(payload_str)
            payload_str = json.dumps(parsed, indent=0, ensure_ascii=False)[2:-2].replace('"', '"')
        except (json.JSONDecodeError, TypeError):
            pass

        if client == self.local_client:
            broker = "local"
        elif client == self.auth_client:
            broker = "auth "
        else:
            broker = "?"

        label = f"[{broker}] {msg.topic}"

        if msg.topic == TPC_LOADS_SET:
            self._process_load_list(payload_str)
        if msg.topic.startswith(TPC_STATUS_TOPIC + "/"):
            self._update_load_state(msg.topic, payload_str)

        self._log_monitor(label, payload_str)

    def _process_load_list(self, payload_str):
        try:
            data = json.loads(payload_str)
            loads = data.get("lds", [])
        except (json.JSONDecodeError, AttributeError):
            return

        for item in self.loads_tree.get_children():
            self.loads_tree.delete(item)

        self.loads = []
        for i, ld in enumerate(loads):
            ld_id = i + 1
            nm = ld.get("nm", f"Load {ld_id}")
            typ = ld.get("typ", "?")
            sta = ld.get("sta", {})
            sta_str = json.dumps(sta) if sta else "—"
            self.loads_tree.insert("", tk.END, values=(ld_id, nm, LOAD_TYPES.get(typ, typ), sta_str))
            self.loads.append({"id": ld_id, "nm": nm, "typ": typ, "sta": sta})

        self.status_var.set(f"Loaded {len(loads)} loads")

    def _update_load_state(self, topic, payload_str):
        try:
            ld_id = int(topic.split("/")[-1])
        except (ValueError, IndexError):
            return
        try:
            data = json.loads(payload_str)
            sta = data.get("sta", {})
        except (json.JSONDecodeError, AttributeError):
            return
        sta_str = json.dumps(sta) if sta else "—"
        for item in self.loads_tree.get_children():
            vals = self.loads_tree.item(item)["values"]
            if len(vals) > 0 and vals[0] == ld_id:
                self.loads_tree.item(item, values=(vals[0], vals[1], vals[2], sta_str))
                break

    # ── Monitor ──────────────────────────────────────────────────────────────
    def _log_monitor(self, label, message):
        if self.pause_var.get():
            return
        filt = self.filter_var.get().strip()
        if filt and filt.lower() not in label.lower() and filt.lower() not in message.lower():
            return

        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        line = f"{timestamp}  {label:12s}  {message}\n"

        self.monitor_text.config(state=tk.NORMAL)
        self.monitor_text.insert(tk.END, line)
        if "ERR" in label or "FAILED" in message or "Error" in message:
            self.monitor_text.tag_add("err", f"end-2l", "end-1l")
            self.monitor_text.tag_config("err", foreground="#f38ba8")
        elif "CONNECTED" in message:
            self.monitor_text.tag_add("ok", f"end-2l", "end-1l")
            self.monitor_text.tag_config("ok", foreground="#a6e3a1")
        elif "DISCONNECTED" in message:
            self.monitor_text.tag_add("warn", f"end-2l", "end-1l")
            self.monitor_text.tag_config("warn", foreground="#fab387")
        elif "CYCLE" in label:
            self.monitor_text.tag_add("cycle", f"end-2l", "end-1l")
            self.monitor_text.tag_config("cycle", foreground="#89b4fa")

        self.monitor_text.see(tk.END)
        self.monitor_text.config(state=tk.DISABLED)

        lines = int(self.monitor_text.index('end-1c').split('.')[0])
        if lines > 5000:
            self.monitor_text.config(state=tk.NORMAL)
            self.monitor_text.delete("1.0", "1000.0")
            self.monitor_text.config(state=tk.DISABLED)

    def _clear_monitor(self):
        self.monitor_text.config(state=tk.NORMAL)
        self.monitor_text.delete("1.0", tk.END)
        self.monitor_text.config(state=tk.DISABLED)

    def _copy_monitor(self):
        content = self.monitor_text.get("1.0", tk.END)
        self.root.clipboard_clear()
        self.root.clipboard_append(content)
        self.status_var.set("Copied monitor content to clipboard")

    def run(self):
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)
        self.root.mainloop()

    def _on_close(self):
        self._do_disconnect()
        self.root.destroy()


if __name__ == "__main__":
    app = MqttTesterGui()
    app.run()
