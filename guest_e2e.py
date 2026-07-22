#!/usr/bin/env python3
"""End-to-end guest CRUD + MQTT auth test on the live OKAS device.

Steps:
  1. Get owner commandToken
  2. Generate a random 8-char guest token client-side
  3. POST /api/auth/guests to create the guest
  4. GET /api/auth/guests to confirm it appears in the list
  5. Exchange the guest token for its own commandToken
  6. Use the guest's commandToken to publish command/sndCmd -> executed
  7. Revoke the guest
  8. Confirm next publish is rejected
  9. Delete the guest
"""
import json
import time
import secrets
import string
import urllib.request
import paho.mqtt.client as mqtt

BASE = "http://127.0.0.1:8080"
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def post(path, body, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode(),
        headers=headers,
        method="POST",
    )
    return urllib.request.urlopen(req, timeout=5)


def get(path, token):
    req = urllib.request.Request(
        BASE + path,
        headers={"Authorization": f"Bearer {token}"},
        method="GET",
    )
    return urllib.request.urlopen(req, timeout=5)


# 1. owner commandToken
OWNER = json.load(open("/home/OhKnx/Data/loadData.json"))[0]["authToken"]
owner_ct = json.loads(post("/api/auth/exchange", {"token": OWNER}).read())["commandToken"]
print(f"[1] Owner commandToken acquired")

# 2. generate a fresh 8-char guest token (Flutter does the same with Random.secure())
def gen_token():
    return "".join(secrets.choice(ALPHABET) for _ in range(8))

GUEST_TOK = gen_token()
GUEST_LBL = f"E2EGuest-{int(time.time())}"
print(f"[2] Generated guest token: {GUEST_TOK}  label: {GUEST_LBL}")

# 3. POST /api/auth/guests as admin (Bearer = owner token)
req = urllib.request.Request(
    BASE + "/api/auth/guests",
    data=json.dumps({
        "label": GUEST_LBL,
        "durationMinutes": 60,
        "token": GUEST_TOK,
    }).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {OWNER}"},
    method="POST",
)
r = json.loads(urllib.request.urlopen(req, timeout=5).read())
guest_id = r["guest"]["id"]
print(f"[3] Created guest id={guest_id} expiresAt={r['guest']['expiresAt']}")

# 4. GET /api/auth/guests and confirm
lst = json.loads(get("/api/auth/guests", OWNER).read())
labels = [g["label"] for g in lst["guests"]]
assert GUEST_LBL in labels, f"guest not in list: {labels}"
print(f"[4] Guest appears in list ({len(labels)} guests total)")

# 5. Exchange the guest token
g_session = json.loads(post("/api/auth/exchange", {"token": GUEST_TOK}).read())
guest_ct = g_session["commandToken"]
print(f"[5] Guest exchange OK: role={g_session['principal']['role']} label={g_session['principal']['label']}")

# 6. Use guest commandToken to toggle a load via MQTT
c = mqtt.Client(client_id="guest-e2e")
seen = []
c.on_message = lambda cli, u, msg: seen.append((msg.topic, msg.payload.decode()))
c.connect("localhost", 1883, 30)
c.loop_start()
c.subscribe([("command/cmdAck", 1), ("status/1", 1)], qos=1)
time.sleep(1)

# toggle ldId=1 (Pendent 1) OFF via guest token
c.publish("command/sndCmd",
          json.dumps({"ldId":1,"typ":"swt","cmd":{"swt":False},"commandToken":guest_ct}),
          qos=1)
time.sleep(2)
acks = [json.loads(p) for t,p in seen if t=="command/cmdAck"]
assert any(a.get("sts")=="executed" for a in acks), f"guest cmd not executed: {acks}"
print(f"[6] Guest command executed: {acks[-1]}")

# 7. Revoke the guest
req = urllib.request.Request(
    BASE + f"/api/auth/guests/{guest_id}/revoke",
    headers={"Authorization": f"Bearer {OWNER}"},
    method="POST",
)
r = json.loads(urllib.request.urlopen(req, timeout=5).read())
print(f"[7] Revoked: revokedAt={r['guest']['revokedAt']}")

# 8. Try to use the guest's commandToken again -> should be rejected
seen[:] = []
time.sleep(1)
c.publish("command/sndCmd",
          json.dumps({"ldId":1,"typ":"swt","cmd":{"swt":True},"commandToken":guest_ct}),
          qos=1)
time.sleep(1.5)
acks = [json.loads(p) for t,p in seen if t=="command/cmdAck"]
err = acks[0].get("err","") if acks else "(no ack)"
print(f"[8] Post-revoke cmd rejected: {err}")
assert "Unauthorized" in err or "revoked" in err.lower()

# 9. DELETE the guest
req = urllib.request.Request(
    BASE + f"/api/auth/guests/{guest_id}",
    headers={"Authorization": f"Bearer {OWNER}"},
    method="DELETE",
)
urllib.request.urlopen(req, timeout=5)
lst = json.loads(get("/api/auth/guests", OWNER).read())
assert GUEST_LBL not in [g["label"] for g in lst["guests"]], "guest still in list"
print(f"[9] Deleted: guest gone ({len(lst['guests'])} guests remain)")

c.loop_stop(); c.disconnect()
print()
print("ALL GUEST CRUD STEPS PASSED.")