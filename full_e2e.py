#!/usr/bin/env python3
"""End-to-end auth verification on the live OKAS device."""
import json
import time
import urllib.request
import paho.mqtt.client as mqtt

OWNER = json.load(open("/home/OhKnx/Data/loadData.json"))[0]["authToken"]
print(f"[1] Owner token: {OWNER}")

req = urllib.request.Request(
    "http://127.0.0.1:8080/api/auth/exchange",
    data=json.dumps({"token": OWNER}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
session = json.loads(urllib.request.urlopen(req, timeout=5).read())
ct = session["commandToken"]
pr = session["principal"]
print(f"[2] Exchange OK: role={pr['role']} label={pr['label']}")
print(f"    commandToken[:50]: {ct[:50]}...")

seen = []
def on_msg(c, u, msg):
    seen.append((msg.topic, msg.payload.decode()))

c = mqtt.Client(client_id="e2e-test-1")
c.on_message = on_msg
c.connect("localhost", 1883, 30)
c.loop_start()
c.subscribe([("command/cmdAck", 1), ("status/+", 1), ("loads/setLoads", 1)], qos=1)
time.sleep(1.5)
print("[3] Subscriber running")

print()
print("=== STEP A: loads/getLoads with commandToken ===")
c.publish("loads/getLoads", json.dumps({"commandToken": ct}), qos=1)
time.sleep(2)
for t, p in [x for x in seen if x[0] == "loads/setLoads"]:
    parsed = json.loads(p)
    nms = [l["nm"] for l in parsed["lds"]]
    print(f"  loads/setLoads -> {len(parsed['lds'])} loads: {nms}")

print()
print("=== STEP B: command/sndCmd WITHOUT token (expect rejection) ===")
seen[:] = []
c.publish("command/sndCmd",
          json.dumps({"ldId": 1, "typ": "swt", "cmd": {"swt": True}}),
          qos=1)
time.sleep(1.5)
for t, p in [x for x in seen if x[0] == "command/cmdAck"]:
    parsed = json.loads(p)
    print(f"  cmdAck: sts={parsed.get('sts')} err={parsed.get('err','')}")
if not [x for x in seen if x[0] == "command/cmdAck"]:
    print("  (no cmdAck received)")

print()
print("=== STEP C: command/sndCmd WITH commandToken for each load ===")
for ldId, name, target in [(1, "Pendent 1", True),
                           (2, "Down Light", True),
                           (3, "Reception ", False)]:
    seen[:] = []
    cmd = {"ldId": ldId, "typ": "swt", "cmd": {"swt": target},
           "commandToken": ct}
    c.publish("command/sndCmd", json.dumps(cmd), qos=1)
    time.sleep(2)
    acks = [x for x in seen if x[0] == "command/cmdAck"]
    states = [x for x in seen if x[0] == f"status/{ldId}"]
    print(f"  ldId={ldId} {name} -> {target}:")
    for t, p in acks:
        parsed = json.loads(p)
        print(f"    cmdAck: sts={parsed.get('sts')} err={parsed.get('err','')}")
    for t, p in states:
        parsed = json.loads(p)
        print(f"    status/{ldId}: {parsed}")

print()
print("=== STEP D: final load list ===")
seen[:] = []
c.publish("loads/getLoads", json.dumps({"commandToken": ct}), qos=1)
time.sleep(2)
for t, p in [x for x in seen if x[0] == "loads/setLoads"]:
    parsed = json.loads(p)
    for ld in parsed["lds"]:
        on_val = ld["sta"].get("on", "?")
        print(f"  {ld['nm']}: on={on_val}")

c.loop_stop()
c.disconnect()