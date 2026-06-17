# Changelog

All notable changes to UNIUN are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.
The `+build` suffix on each version (e.g. `1.1.0+2`) is the Android `versionCode` /
iOS build number — it increases by **1 on every store upload**, even if the user-facing
version is unchanged.

See [docs/RELEASING.md](docs/RELEASING.md) for the full release procedure.

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

[1.1.0]: #110--2026-06-17
[1.0.0]: #100--initial-release
