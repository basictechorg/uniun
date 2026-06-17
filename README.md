# UNIUN

A decentralized, **offline-first** social and knowledge network built on the Nostr protocol. Notes, channels, DMs, and a personal knowledge graph all live in one Flutter app — synced to a Nostr relay you control, with an on-device AI assistant (Shiv) that reasons over your own saved notes without ever calling the cloud.

- **No backend you don't own.** Bytes flow through your relay; the app itself talks to Isar (a local DB), and a Gateway isolate talks to relays over WebSocket.
- **On-device AI.** Shiv runs via `flutter_gemma` (Qwen3 0.6B / DeepSeek R1 / Gemma 4 E2B / Gemma 4 E4B). GPU-accelerated on Android (OpenCL/WebGPU) and iOS (Metal). Prompts never leave the device.
- **Notes are forever.** No delete. No soft-delete. The Nostr event graph *is* the knowledge graph — every `e` tag an edge, every `t` tag a topic node.
- **Content-addressed media.** Photos / videos / files attach via NIP-92 `imeta` + Blossom (NIP-B7). The same blob across many notes = one upload + one cache entry per device.

For the deeper architecture and conventions, see `docs`.

---

## Running locally

Requirements:

- Flutter SDK **>= 3.11.0** (channel: stable). Verify with `flutter --version`.
- Dart SDK is bundled with Flutter — no separate install.
- Platform toolchain for whichever target you're building (Android Studio + JDK for Android, Xcode for iOS/macOS, Visual Studio with C++ workload for Windows).

Three steps from a clean checkout:

```bash
# 1. Resolve packages
flutter pub get

# 2. Regenerate Isar / Freezed / Injectable / json_serializable code
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run on a connected device or simulator
flutter run
```

You **must** run step 2 every time you change a `@freezed`, `@Collection`, or `@injectable`-annotated class. The build order (freezed before isar_generator) is locked in `pubspec.yaml` under `global_options`.

To pick a specific target when several are attached:

```bash
flutter devices              # list available devices
flutter run -d <device-id>   # e.g. emulator-5554, macos, windows
```

The first launch will prompt you to download an AI model (~700 MB to ~3 GB depending on the model). Models live in flutter_gemma's managed storage — uninstall via Settings → AI Model.

---

## Platform support

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | ✅ Supported | Min SDK 21. GPU inference via OpenCL. QR scan, image / video / file picker, on-device AI all work. |
| **iOS** | ✅ Supported | iOS 13+. Metal-backed inference. Universal Links wired to `www.uniun.in`. |
| **macOS** | ✅ Supported | Tested locally. Isar, Gateway sync, and on-device AI all work. |
| **Windows** | ✅ Supported | Tested locally. NPU dispatch available on Intel Lunar/Panther Lake via `flutter_gemma` 0.16.x. |

All four platforms compile from the same `lib/` codebase; there is no platform fork.

---

## Project layout

```
lib/                  Flutter app (see CLAUDE.md for the layer rules)
  ├── core/           Routing, theme, constants, base classes
  ├── data/           Isar models + repository implementations
  ├── domain/         Freezed entities, abstract repos, use cases
  ├── gateway/        Relay sync isolate (WebSocket + inbound handlers)
  ├── features/       Feature modules (vishnu, brahma, shiv, channels, dm, …)
  └── common/         Cross-feature widgets and helpers
uniun-backend/        Go Nostr relay (Khatru + BadgerDB + Blossom + Azure)
docs/                 Architecture notes (media subsystem, GraphRAG, …)
```

---

## Contributing

Read `docs` end-to-end before touching code. The behavioural guardrails there (no NIP-09, no Reddit-style models, `isar_community` only, Freezed 3.x `abstract class`, all UI strings via `AppLocalizations`) are enforced — they are not stylistic preferences.

Bug reports and feature requests go through the issue tracker. Don't commit generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`); they are reproduced by `build_runner` / `flutter gen-l10n`.
