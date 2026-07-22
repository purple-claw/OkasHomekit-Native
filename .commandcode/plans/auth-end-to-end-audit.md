# Plan: Verify & harden the auth flow end-to-end

## What the user is asking for

The user said: "the authentication is missing in the current implementation, also
fix that for reference use the frontend and on how to implement the admin token
auth and the Guest access management, verify whether all the topics are correctly
handled in current code implementation."

Three asks:

1. **Admin token auth** — derive the owner token from MAC, surface it, exchange
   it for a session `commandToken`, and prove that MQTT `loads/getLoads` and
   `command/sndCmd` work end-to-end with that token.
2. **Guest access management** — prove the guest CRUD endpoints
   (`GET/POST/PUT/PATCH/DELETE /api/auth/guests`, `/api/auth/guests/:id/revoke`)
   work, that guest tokens authorize MQTT traffic, and that revocation / expiry
   actually stop them.
3. **Topic audit** — verify every topic in the mosquitto ACL is correctly
   handled by the backend (no `command/+/response`, no `home/+/light` etc. that
   the frontend publishes but the backend never reads).

## What the audit found (already in the explore report)

The Node auth implementation is **complete in source**:

- `Auth/authService.js` (431 lines) implements owner-token-from-MAC,
  HMAC-signed 12 h `commandToken`, guest CRUD with scrypt+salt hashed storage,
  rate-limit on `/verify` and `/exchange`, CORS preflight, Apache-friendly
  `X-Forwarded-For` rate-limit key, atomic store writes.
- `Index.js` calls `startAuthService()` before HomeKit and `stopAuthService()`
  on shutdown.
- `Mqtt/mqttClnt.js:222` gates `loads/getLoads` and `command/sndCmd` via
  `global.authorizeMqttPayload(pld)` — which already accepts `commandToken`
  (preferred), `authToken`, or `token`.
- `Mqtt/mqttClnt.js` also redacts `commandToken`/`authToken`/`token` from
  the JSON logged on every received message so tokens never appear in the
  board log file.
- Frontend (`token_auth_service.dart`, `direct_mqtt_service.dart`) acquires
  the session via HTTP, stores it in `flutter_secure_storage`, and the
  `DirectMQTTService.publish()` helper splices `commandToken` into every
  outbound payload.
- `www/getAdminToken.php` and `www/deviceInfo.html` surface the plaintext
  owner token for first-time commissioning.
- `runOnce/okas-auth-proxy.conf` + `scripts/setup-auth-webserver.sh` install
  the Apache reverse proxy from `/api/*` → `127.0.0.1:8080`.

## What was actually wrong

Our test earlier failed because we sent anonymous MQTT to `command/sndCmd`
without a `commandToken` — the auth layer correctly rejected it. Once we
exchanged the owner token via `/api/auth/exchange` and attached the resulting
`commandToken`, the same payload was accepted (we already verified this with
the auth check returning a successful session; we have not yet re-run the
load-toggle with the token attached — that is the next step).

## What we will do

### 1. On-device state verification (read-only)

Confirm on `root@okas-homekit.local`:
- `AuthData/` exists, root-owned 0700, `authStore.json` is 0600.
- Apache `/etc/apache2/conf-enabled/okas-auth-proxy.conf` is enabled.
- Apache modules `proxy`, `proxy_http`, `headers` are loaded.
- `127.0.0.1:8080/api/health` returns `{ success: true }`.
- `/api/auth/exchange` works for the current owner token.

If any of these are missing, run `scripts/setup-auth-webserver.sh` (sudo).

### 2. End-to-end happy-path with commandToken

For the three loads (Pendent 1 / Down Light / Reception):

1. `GET http://localhost/api/health` → expect 200.
2. `POST http://localhost/api/auth/exchange` with the owner token → expect
   `{ success, principal, commandToken, mqtt }`.
3. Subscribe to `command/cmdAck`, `status/+`, `okas/knx/#` locally.
4. Publish `loads/getLoads` with `commandToken` → expect a fresh
   `loads/setLoads` and per-load `status/{1,2,3}` retention.
5. Toggle each load via `command/sndCmd` with `commandToken` → expect
   `cmdAck` "received" then "executed" + KNX write confirmed in Python logs
   + `status/{1,2,3}` updated.
6. Confirm `commandToken` redaction in the log file
   (`/home/OhKnx/logs/JUL2026.log` or wherever `dbg.Inf('MQTT: Message on ...')`
   writes to) — no token leakage.

### 3. Guest CRUD end-to-end

1. As admin, `POST /api/auth/guests` with a fresh 8-char guest token +
   label + duration → expect 201 with the guest public shape.
2. `GET /api/auth/guests` → list shows the new guest.
3. Exchange the guest token at `/api/auth/exchange` → expect `commandToken`
   whose `principal.role` is `guest` and `principal.label` matches.
4. Use that `commandToken` to publish `command/sndCmd` → expect "executed".
5. `POST /api/auth/guests/:id/revoke` → next MQTT publish is rejected.
6. `DELETE /api/auth/guests/:id` → guest gone from list.

### 4. Topic audit — fix any orphan topics

The Flutter frontend publishes/subscribes to topics the backend **never**
handles:

| Topic | Source | Backend handler |
|---|---|---|
| `command/+/response` | `mqtt_command_service.dart:85` (subscribed) | **none** |
| `home/+/light`, `home/+/temperature`, `home/+/status` | `mqtt_command_service.dart` | **none** |
| `status/sndStatus`, `command/recvCmd` | `okas_mqtt_tester.py` (legacy test tool) | **none** |
| `rooms/add`, `rooms/get` | `direct_mqtt_service.dart` (publish only) | **none** |
| `loads/test`, `okas/knx/test` | observed on the live broker | **none** (probably stale retained) |

Decision: do not add handlers for these — they're either legacy test tools
or stubs in the frontend. Instead:

- Audit the **active** frontend (`DirectMQTTService`, not the older
  `MQTTService`) and confirm it only publishes to topics that have a backend
  handler (`command/sndCmd`, `loads/getLoads`).
- Note the legacy `mqtt_command_service.dart` as deprecated (comment-only
  fix; no functional change).
- Purge stale retained messages on the broker so old test topics don't
  confuse diagnostics (a one-shot `mosquitto_pub -r -n` cleanup).

### 5. Hardening pass

If any of these are missing in the code, add them:

- **`Mqtt/mqttClnt.js` log redaction** — already in place (lines 211-215);
  double-check it covers `commandToken` (it does).
- **Audit log of auth events** — `authService.js` already logs via
  `dbg.Inf/Wrn/Err`. Confirm `/api/auth/guests` create/revoke/delete are
  emitted to the same log file. They already are via the
  `createGuest/revokeGuest/deleteGuest` code paths (each returns the
  `publicPrincipal` shape); add explicit `dbg.Inf` lines for visibility if
  missing.
- **Token rotation** — out of scope; owner token only regenerates when the
  MAC-derived hash changes (i.e. never under normal operation). The
  `commandToken` already rotates every 12 h automatically.

### 6. Deliverables

- Updated tests demonstrating the full happy-path + guest flow with logs
  captured.
- One-shot MQTT retained-message purge (test cleanup).
- A short `README-auth.md` doc (in `Okas-Homekit-Working/Auth/`) describing
  how to verify auth end-to-end from the host, so the next operator can
  reproduce it without reading the entire auth source.

## Out of scope

- Refactoring the legacy `MQTTService` class out of the frontend (it isn't
  wired into any live UI).
- Adding web-based admin UI for guest management (the Flutter screen
  already exists and the API endpoints are working).
- Changing the 12 h `commandToken` TTL.
- Restructuring the Apache reverse proxy (it is correct as-is).

## Acceptance criteria

The task is done when, on the live device, all of the following are
demonstrably true in the journalctl log:

1. `GET /api/health` returns `{ success: true }`.
2. `POST /api/auth/exchange` returns a `commandToken` for both owner and
   guest tokens.
3. Publishing `loads/getLoads` with the owner's `commandToken` produces a
   `loads/setLoads` response.
4. Publishing `command/sndCmd` with the owner's `commandToken` produces a
   `cmdAck` "received" + "executed" + the actual KNX write appears in the
   Python bridge log + the corresponding `status/{N}` topic updates.
5. Publishing `command/sndCmd` with **no** `commandToken`/`authToken` is
   rejected with `cmdAck` "Unauthorized".
6. A guest token works for steps 3-4, but stops working after
   `POST /api/auth/guests/:id/revoke`.
7. The log file `/home/OhKnx/logs/JUL2026.log` does **not** contain any
   `commandToken`/`authToken` substring.