#!/usr/bin/env python3
"""Comprehensive load-type audit on the live device."""
import json
import time
import urllib.request
import paho.mqtt.client as mqtt

OWNER = json.load(open("/home/OhKnx/Data/loadData.json"))[0]["authToken"]
ct = json.loads(urllib.request.urlopen(urllib.request.Request(
    "http://127.0.0.1:8080/api/auth/exchange",
    data=json.dumps({"token": OWNER}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
), timeout=5).read())["commandToken"]

seen = []
def on_msg(c, u, msg):
    seen.append((msg.topic, msg.payload.decode()))

c = mqtt.Client(client_id="all-test")
c.on_message = on_msg
c.connect("localhost", 1883, 30)
c.loop_start()
c.subscribe([("command/cmdAck", 1), ("status/+", 1), ("loads/setLoads", 1)], qos=1)
time.sleep(1.5)

c.publish("loads/getLoads", json.dumps({"commandToken": ct}), qos=1)
time.sleep(2)
loads_by_type = {}
for t, p in seen:
    if t == "loads/setLoads":
        d = json.loads(p)
        for i, ld in enumerate(d["lds"]):
            loads_by_type.setdefault(ld["typ"], []).append((i + 1, ld["nm"]))
        break
print("=== Loads by type ===")
for typ, loads in loads_by_type.items():
    for ldId, name in loads:
        print(f"  {typ}: ldId={ldId} {name}")

# Test scenarios per type
test_cmds = {
    "swt": [1, 2, 3, 7, 8],  # ldIds to swt=true (use first load of each type)
}

print()
print("=== Switch ON/OFF ===")
for ldId, name in loads_by_type.get("swt", [])[:1]:
    seen[:] = []
    c.publish("command/sndCmd", json.dumps({"ldId": ldId, "typ": "swt", "cmd": {"swt": True}, "commandToken": ct}), qos=1)
    time.sleep(2)
    state = [json.loads(p) for t, p in seen if t == f"status/{ldId}"]
    print(f"  swt=true ldId={ldId} {name}: {state[-1] if state else '(no status)'}")

print()
print("=== Dimmer ON / bri= ===")
for ldId, name in loads_by_type.get("dim", [])[:1]:
    seen[:] = []
    c.publish("command/sndCmd", json.dumps({"ldId": ldId, "typ": "dim", "cmd": {"swt": True}, "commandToken": ct}), qos=1)
    time.sleep(2)
    state = [json.loads(p) for t, p in seen if t == f"status/{ldId}"]
    print(f"  swt=true ldId={ldId} {name}: {state[-1] if state else '(no status)'}")
    seen[:] = []
    c.publish("command/sndCmd", json.dumps({"ldId": ldId, "typ": "dim", "cmd": {"bri": 60}, "commandToken": ct}), qos=1)
    time.sleep(2)
    state = [json.loads(p) for t, p in seen if t == f"status/{ldId}"]
    print(f"  bri=60   ldId={ldId} {name}: {state[-1] if state else '(no status)'}")

print()
print("=== Curtain pos= ===")
for ldId, name in loads_by_type.get("cur", [])[:1]:
    seen[:] = []
    c.publish("command/sndCmd", json.dumps({"ldId": ldId, "typ": "cur", "cmd": {"pos": 75}, "commandToken": ct}), qos=1)
    time.sleep(2)
    state = [json.loads(p) for t, p in seen if t == f"status/{ldId}"]
    print(f"  pos=75   ldId={ldId} {name}: {state[-1] if state else '(no status)'}")

c.loop_stop(); c.disconnect()
print("\nDone.")