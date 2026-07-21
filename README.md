# OKAS Homekit — Frontend(Native)

**One line:** A Flutter cross-platform app that puts your KNX-connected home in your pocket, with real-time MQTT control and a slick dark UI.

---

You know that moment when you're cozy in bed and realise the living room light is still on? Yeah. This app fixes that — and a whole lot more.

**OKAS Smart Home** is the mobile face of the OKAS HomeKit ecosystem. It talks to the backend bridge over MQTT and HTTP, so you can flick switches, dim lights, roll curtains, tweak your HVAC, and trigger scenes — all from your phone. No cloud required. No subscription. Just your home, doing what you tell it.

### What it does

- **Live device control** — Toggle loads, dimmers, RGB lights, tunable whites, fans, curtains, and scenes in real time through MQTT.
- **KNX gateway integration** — Every tap flows through to the KNX bus via the backend bridge. No middlemen, no delays.
- **Dark-first UI** — Built with Material 3 and a custom dark colour scheme, because smart home control looks better in the dark.
- **Cross-platform** — Runs on Android, iOS, Web, Linux, macOS, and Windows from a single Flutter codebase.

### Built with

- **Flutter** + **Dart** — because writing UI should be fun.
- **Provider** — state management that just works.
- **MQTT** — for fast, bidirectional communication with the backend.
- **hap-nodejs**-powered bridge — the backend speaks HomeKit, but the app speaks MQTT directly.

### Quick start

```bash
cd frontend/smart_home_animation
flutter pub get
flutter run
```

Point the app at your OKAS bridge IP on first launch — the rest is automatic.

### Project structure

```
lib/
├── api/          # HTTP/MQTT API layer & constants
├── bloc/         # Business logic components
├── core/         # App shell, theme, shared widgets
├── features/     # Feature modules (screens & flows)
├── providers/    # State providers
└── services/     # MQTT client, auth, and platform services
```

---

*Made for the OKAS ecosystem. Pull requests, ideas, and late-night "what if we added…" thoughts are always welcome.*
