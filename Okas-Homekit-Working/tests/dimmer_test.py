#!/usr/bin/env python3
"""Audit dimmer feedback flow on the live device."""
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

c = mqtt.Client(client_id="dim-test")
c.on_message = on_msg
c.connect("localhost", 1883, 30)
c.loop_start()
c.subscribe([("command/cmdAck", 1), ("status/+", 1), ("okas/knx/#", 1), ("loads/setLoads", 1)], qos=1)
time.sleep(1.5)

# Get load list
c.publish("loads/getLoads", json.dumps({"commandToken": ct}), qos=1)
time.sleep(2)

dimmers = []
for t, p in seen:
    if t == "loads/setLoads":
        d = json.loads(p)
        for i, ld in enumerate(d["lds"]):
            if ld["typ"] == "dim":
                dimmers.append((i + 1, ld["nm"]))
                print(f"Dimmer ldId={i+1}: {ld['nm']}")
        break

# For each dimmer, try a switch-on, then a brightness change
for ldId, name in dimmers:
    seen[:] = []
    cmd = {"ldId": ldId, "typ": "dim", "cmd": {"swt": True}, "commandToken": ct}
    c.publish("command/sndCmd", json.dumps(cmd), qos=1)
    time.sleep(2)
    ack_msgs = [json.loads(p) for t, p in seen if t == "command/cmdAck"]
    state_msgs = [json.loads(p) for t, p in seen if t == f"status/{ldId}"]
    print(f"\nldId={ldId} {name} swt=true:")
    for a in ack_msgs:
        print(f"  cmdAck: sts={a.get('sts')} err={a.get('err','')}")
    for s in state_msgs:
        print(f"  status/{ldId}: {s}")

    seen[:] = []
    cmd = {"ldId": ldId, "typ": "dim", "cmd": {"bri": 75}, "commandToken": ct}
    c.publish("command/sndCmd", json.dumps(cmd), qos=1)
    time.sleep(2)
    ack_msgs = [json.loads(p) for t, p in seen if t == "command/cmdAck"]
    state_msgs = [json.loads(p) for t, p in seen if t == f"status/{ldId}"]
    print(f"ldId={ldId} {name} bri=75:")
    for a in ack_msgs:
        print(f"  cmdAck: sts={a.get('sts')} err={a.get('err','')}")
    for s in state_msgs:
        print(f"  status/{ldId}: {s}")

c.loop_stop(); c.disconnect()
print("\nDone.")