# Changelog

All notable changes to UNIUN are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.
The `+build` suffix on each version (e.g. `1.1.0+2`) is the Android `versionCode` /
iOS build number — it increases by **1 on every store upload**, even if the user-facing
version is unchanged.

See [docs/RELEASING.md](docs/RELEASING.md) for the full release procedure.

---

## [2.2.0] — 2026-08-02

This release expands UNIUN's inference, identity, and offline networking capabilities.

### Added
- **UNIUN cloud inference.** Use hosted AI models from Shiv with built-in model selection,
  credit usage, and mobile payment support alongside on-device inference.
- **QR identity recovery.** Sign in on another device by scanning a secure QR code instead of
  manually transferring identity credentials.
- **Offline mesh sync.** Nearby devices can discover each other over local transports and securely
  synchronize notes, follows, groups, Manas collections, Ganas, and other user-owned data.
- **Surrounding notes.** Discover notes shared by nearby mesh peers in a dedicated feed.

### Changed
- Onboarding interest recommendations are now loaded from UNIUN's service so suggested accounts
  can be updated without an app release.
- Expanded repository, gateway, mesh, and integration test coverage.

### Fixed
- Improved cloud-model selection, credit accounting, inference UI, login, and sync reliability.

## [2.1.0] — 2026-07-03

A follow-up release focused on **theming**, **reliability of the followed-notes badge**, and a
significant expansion of the test suite.

### Added
- **Dark mode.** Full dark theme across every screen and component, with a new theme system built
  on `AppCustomColors` and a `ThemeCubit`. A **theme-mode setting** (System / Light / Dark) is
  available in Settings and persists across launches via `AppSettingsStore`. All shared widgets —
  note cards, composer, floating nav, QR views, thread views, drop indicators, media views, etc. —
  were updated to use theme-aware colors instead of hard-coded values.
- **Broader test coverage.** New tests for the theme system (`AppThemeMode`, `ThemeCubit`, theme-mode
  persistence, Settings theme row), the media pipeline (`BlossomClient`, `MediaCacheDataSource`,
  `MediaRepositoryImpl`, media use cases, gallery/detail cubits, media tile & settings row, and an
  end-to-end media pipeline integration test), and additional common-layer tests.

### Changed
- **Followed-notes badge is now derived from unread rows.** The unread-reference indicator on
  followed notes is computed directly from the unread rows rather than a cached counter, so the
  badge stays consistent with what the user actually sees.

### Fixed
- CI pipeline fix.
- Blossom media-upload failure path hardened, with matching backend `DEPLOY.md` guidance.

---

## [2.0.0] — 2026-06-30

A major release: the public **Channels** feature is now **Groups**, the app gets a visual
redesign, and UNIUN goes **multilingual** with full Hindi support.

### Added
- **Multi-language support — English + Hindi.** UNIUN can now run fully in **Hindi** (हिन्दी,
  Devanagari). An in-app language switcher is available on the welcome screen (a quick EN / हिन्दी
  toggle), on a dedicated **language-selection page**, and in **Settings**; the choice persists
  across launches. Several more languages are listed as "coming soon". *(The Hindi translation is
  machine-generated and pending native-speaker review.)*
- **Onboarding interest picker.** After creating an identity, new users pick topics they care about;
  UNIUN batch-follows a set of house accounts in a single transaction (one Kind-3 contact-list
  republish) so the feed is alive from the first scroll instead of empty.
- **Reporting & content moderation (NIP-56).** Users can file **Kind 1984** reports on notes and
  users (nudity, spam, impersonation, illegal content, etc.), optionally block the author in the
  same step, and review their own report history. Reporting a note also tombstones it locally so it
  leaves the reporter's feed and threads.

### Changed
- **Channels are now "Groups".** The public-chat feature was renamed **Channel → Group** across the
  entire app — UI, all strings, and the codebase — while preserving existing on-device data.
  ("Group ID" terminology is kept where users copy/share identifiers.)
- **Redesigned application.** A broad visual refresh across the app's screens and components.
- **Smarter on-device AI scheduling.** Improvements to the inference scheduler that arbitrates chat,
  foreground, knowledge-extraction, and background (Gana / Nataraj) AI work so the device stays
  responsive under contention.
- **Apple App Store compliance.** Edit-profile, Gana, and header fixes plus the other changes
  required to pass App Store review; the companion website was shipped.

### Fixed
- Direct thread replies that were missing their NIP-10 reply marker.
- Shiv UI not refreshing in some states.
- Draft deep-link handling.
- Assorted bug fixes and background-worker stability improvements.

---

## [1.3.0] — 2026-06-24

### Added
- **Manas — scoped note collections.** Users can group their notes into named **Manas** and use
  them to scope where AI looks. Picking a Manas narrows Shiv's RAG retrieval, Gana's input pool,
  and the composer-chat context to just that collection (falling back to the whole library when
  none is selected). Manas search now includes drafts and the user's own notes.
- **Nataraj — AI swipe-deck idea generator.** A swipe deck that synthesizes 2–3 of the user's own
  notes into a single new note suggestion, reusing the on-device generation substrate. Cards are a
  local cache, not Nostr events. (Shipped as "Manthan", renamed to **Nataraj** before release.)
- **Gana — autonomous AI agents.** User-owned agents that watch an input surface, infer over
  selected Manas(es), and autonomously publish. Includes scheduled/background generation
  (own isolate + own Isar) and a foreground engine. The trigger config was collapsed into a single
  **"When should this run?"** preset radio (five presets covering the trigger matrix).
- **Composer-chat — inline AI in the composer.** Tap the avatar in any composer (thread / channel /
  DM / private channel) to pick a Manas and chat with an on-device model grounded in the surface's
  recent messages plus the selected Manas.
- **Embed-by-value note sharing with full-note composer.** The share sheet now carries the original
  note **by value** as a self-contained `embeddedNoteJson` snapshot (no `q`/`k`/`p` pointer, no Isar
  lookup, retention-immune) and lets the user author a full note — text, references, and images —
  alongside the embed. The snapshot's signature is verified once at inbound; failures render an
  "unverified" badge.
- **Receive shares from other apps into UNIUN.** UNIUN now registers as a system share target, so
  content shared from other apps lands in the composer.
- **DM replies.** Direct messages support replying to a specific message.
- **OpenRouter (cloud) LLM backend, opt-in.** A backend-agnostic `LlmRepository` now dispatches
  between the on-device `localGemma` runner and a remote **OpenRouter** backend; API keys are stored
  in `flutter_secure_storage` (Keychain / Keystore), never in Isar or SharedPreferences.
- **Media attachments in drafts + BlurHash placeholders** for smoother image loading.
- **"How it works" intro carousel** on the onboarding entry screen.
- **Reddit-style source attribution** shown in Shiv answers.
- **Configurable recent-sync window.** History sync from relays can be capped to a configurable
  recent window to limit how far back the Gateway pulls.
- **Dockerized backend.** The Go relay (`uniun-backend/`) now ships with a Docker setup for
  reproducible deployment.

### Changed
- **On-device AI generation moved to the main isolate** (off the dedicated isolate) for the
  foreground path, with a UI performance pass across onboarding and the feed.
- **Per-user cap on AI note generation** plus assorted generation-flow UI improvements.
- Removed the color picker from Manas.
- Updated `flutter_gemma`.

### Fixed
- Shiv: sanitize the live-streaming message bubble and anchor the Shiv persona near the question.
- Guard against `add`/`emit` after BLoC close during long LLM generation (no more
  "emit after close" crashes on slow inference).
- Saved-note logic bugs.
- Manas search missing drafts and own notes.
- Background worker stability fixes.

---

## [1.1.0] — 2026-06-17

### Added
- **Media support (images, video, files).** Notes, channel messages, DMs, and private-channel
  messages can now carry attachments. Uploads go through the **Blossom** content-addressed
  blob store (BUD-01), and each attachment is described on the event with a NIP-92 `imeta`
  tag. Attachments are stored on `NoteModel.attachments` and joined to on-device files by
  SHA-256 via `MediaCacheModel`.
- **Save media to device.** Media blobs referenced by a note can be downloaded and persisted
  to local storage; the gallery lets the user remove them again (user-driven, no automatic GC).
- **Markdown rendering** for note text.

### Changed
- **Redesigned welcome / front page.** The onboarding entry screen was reworked for a cleaner
  first-run experience. (Design spec: `docs/ui-ux/2026-06-17-welcome-screen-redesign-design.md`.)
- **Shiv (AI) ignores raw media.** The RAG pipeline no longer feeds media payloads into the
  model, so on-device inference stays focused on note text.
- General UI polish across the feed, media viewer, and back-button behaviour.

### Fixed
- DM and feed bugs — channel routing issue, feed/DM sync glitches, and assorted general bugs.
- DeepSeek R1 model failing to load/run.
- Production builds no longer upload debug logs.

---

## [1.0.0] — Initial release

First public release of UNIUN — a decentralized, offline-first social and knowledge network
built on the Nostr protocol.

### Added
- **Vishnu** — chronological Kind 1 note feed with offline-first Isar storage and unread tracking.
- **Brahma** — note composition and publishing, with reference (graph-edge) support and drafts.
- **Shiv** — on-device AI assistant (`flutter_gemma`) running GraphRAG over the user's saved notes,
  with no cloud calls.
- **Channels** — public chat (NIP-28: Kind 40 create / 41 metadata / 42 message) with QR join.
- **Private channels** — encrypted group messaging with admin-controlled membership.
- **DMs** — private direct messages (NIP-17 / NIP-44 encryption).
- **Saved notes** and **followed notes** (subscribing to a note's reference graph).
- **Sharing** — NIP-18 quote/share across feed, channels, and DMs.
- Nostr identity onboarding (key generation + import), local-only private key storage.

[2.0.0]: #130--2026-06-30
[1.3.0]: #114--2026-06-24
[1.1.0]: #110--2026-06-17
[1.0.0]: #100--initial-release
