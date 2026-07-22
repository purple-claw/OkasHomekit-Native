# OKAS HomeKit — Auth End-to-End Verification

This document describes how to verify the authorization layer end-to-end on a
running board. It exists so the next operator (or CI) can reproduce the auth
tests without reading the entire `authService.js` source.

## Architecture (one paragraph)

The auth HTTP API is served by `Auth/authService.js` on `127.0.0.1:8080`
(loopback only). Apache reverse-proxies `/api/*` to it (see
`runOnce/okas-auth-proxy.conf`). The MQTT broker (`localhost:1883` anonymous,
`0.0.0.0:1884` with `okasapi` / `okas1234`) is the same Mosquitto instance;
authorization on the MQTT path is enforced at the **application layer** by
`Mqtt/mqttClnt.js`, which calls `global.authorizeMqttPayload(payload)` for
every incoming message on `loads/getLoads` and `command/sndCmd`. Three
credentials are accepted in priority order: `commandToken` (short-lived
HMAC-signed session token, preferred), `authToken`, or `token` (long-lived
8-char base32 token, fallback).

## On-device prerequisites

```bash
ls -la /home/OhKnx/AuthData/            # root:root 0700, authStore.json 0600
ls -la /etc/apache2/conf-enabled/ | grep okas   # okas-auth-proxy.conf symlink
apache2ctl -M | grep -E 'proxy|headers' # proxy, proxy_http, headers modules loaded
curl -sv http://127.0.0.1:8080/api/health     # {"success": true}
curl -sv http://127.0.0.1/api/health          # same, via Apache
```

If any of the above are missing:

```bash
sudo bash /home/OhKnx/scripts/setup-auth-webserver.sh
systemctl restart apache2
```

## Getting the owner token

```bash
TOKEN=$(python3 -c 'import json; print(json.load(open("/home/OhKnx/Data/loadData.json"))[0]["authToken"])')
echo "$TOKEN"     # 8-char base32
```

## Exchanging for a commandToken (TTL: 12 h)

```bash
curl -s -X POST http://127.0.0.1/api/auth/exchange \
     -H 'Content-Type: application/json' \
     -d "{\"token\":\"$TOKEN\"}" | jq '{principal, commandToken, mqtt}'
```

Use the `commandToken` on every MQTT publish to `loads/getLoads` or
`command/sndCmd`:

```bash
CT=<commandToken from above>
mosquitto_pub -h localhost -p 1883 \
     -t 'loads/getLoads' \
     -m "{\"commandToken\":\"$CT\"}"
mosquitto_pub -h localhost -p 1883 \
     -t 'command/sndCmd' \
     -m "{\"ldId\":1,\"typ\":\"swt\",\"cmd\":{\"swt\":true},\"commandToken\":\"$CT\"}"
```

Without the token, the same publishes are rejected with
`{"sts":"error","err":"Unauthorized, expired, or revoked token."}` on
`command/cmdAck`.

## Guest management

Create a guest (admin-only). Token must be 8-char base32 generated
client-side; the server only stores its scrypt hash.

```bash
GUEST_TOK=$(python3 -c "import secrets,string; print(''.join(secrets.choice('ABCDEFGHJKLMNPQRSTUVWXYZ23456789') for _ in range(8)))")

curl -s -X POST http://127.0.0.1/api/auth/guests \
     -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' \
     -d "{\"label\":\"Guest A\",\"durationMinutes\":60,\"token\":\"$GUEST_TOK\"}"
```

List, revoke, update, delete:

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1/api/auth/guests
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
     http://127.0.0.1/api/auth/guests/<id>/revoke
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
     -d '{"label":"Guest A renamed","durationMinutes":120}' \
     http://127.0.0.1/api/auth/guests/<id>
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
     http://127.0.0.1/api/auth/guests/<id>
```

Guests exchange their token the same way as the owner:

```bash
curl -s -X POST http://127.0.0.1/api/auth/exchange \
     -H 'Content-Type: application/json' \
     -d "{\"token\":\"$GUEST_TOK\"}"
```

A guest `commandToken` is bound to the guest principal: revoking the
guest immediately invalidates that `commandToken` because it carries the
guest's `id` and the server's `signingKey` signature, and
`verifyCommandToken` rejects revoked principals.

## Token storage

- `Data/loadData.json` `data[0].authToken` — the plaintext owner token. Read
  by `www/deviceInfo.html` and `www/getAdminToken.php` for first-time
  commissioning.
- `AuthData/authStore.json` (mode 0600) — scrypt-hashed principals +
  32-byte HMAC signing key. Never readable by Apache/PHP.

## Reproduction scripts

- `/tmp/full_e2e.py` (deployed to the device during verification): owner
  token → exchange → 3 loads with commandToken → anonymous rejection.
- `/tmp/guest_e2e.py`: full guest CRUD + revocation loop.

Both scripts are idempotent — they create and clean up their own data.

## Audit checklist

Run these and confirm:

```bash
# 1. CommandToken never appears in log file
grep -c commandToken /home/OhKnx/www/Logs/JUL2026.log     # → 0
grep -c authToken /home/OhKnx/www/Logs/JUL2026.log        # → 0

# 2. Per-load status topics update on every command execution
mosquitto_sub -h localhost -p 1883 -t 'status/+' -v &    # in one shell
mosquitto_pub -h localhost -p 1883 \
     -t 'command/sndCmd' \
     -m "{\"ldId\":1,\"typ\":\"swt\",\"cmd\":{\"swt\":true},\"commandToken\":\"$CT\"}"
# Expect: status/1 {typ:swt, sta:{on:true}, ts:...}
```