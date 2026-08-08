# Proposal — Encrypted local backup & restore

One file, one passphrase, one tap. Lets a user move their entire UNIUN identity + local state to a new device, or recover after reinstall, without depending on the relay's retention or any cloud service.

---

## Why

UNIUN is fully decentralized — there is no signup server to "log back in" through. Today, reinstalling the app and re-importing the nsec recovers only what the relay still has and can rebroadcast:

- Own notes (Kind 1) — yes, relay has them
- Followed users (Kind 3) — yes
- DMs (Kind 1059 gift wraps) — yes, *but* the decrypted Kind 14 plaintext is reconstructed locally, slow on a fresh install
- Channel memberships — partial; only what's reflected in events

Data that is **not on any relay** is lost on reinstall:

- Drafts that were never published (NIP-37 Kind 31234, local-only)
- Saved-note bookmarks (`SavedNoteModel`)
- Followed-note subscriptions (`FollowedNoteModel`)
- Shiv AI conversations + branching tree (`ShivConversationModel`, `ShivMessageModel`)
- Memory nodes (`MemoryNodeModel`)
- Reports the user filed (`ReportModel`)
- Blocked users list (`BlockedUserModel`)
- Unread cursors (`UnreadNoteModel` — unified across feed/group/DM, not per-surface models)
- App settings + selected AI model name
- Custom relay list overrides
- Private group MLS ratchet state (security-critical, see "Relay safety" below)

The backup feature captures all of this, encrypts it under a passphrase the user controls, and lets them restore it on any device that has the app installed.

---

## File format

```
filename:  uniun-backup-<npub-prefix>-<YYYYMMDD>.uniun
on disk:   { format, header, encrypted_body }
  header (plaintext):
    format_version: "uniun-backup-v1"
    npub:           "npub1..."
    salt:           <base64 16 bytes>
    kdf_iters:      200000
    created_at:     <unix>
    app_version:    "1.3.0"
  encrypted_body:
    AES-256-GCM
    key = PBKDF2-SHA256(passphrase, salt, kdf_iters, 32)
    iv  = random 12 bytes (prepended to ciphertext)
    aad = canonical bytes of the header
```

The header is plaintext so the Import screen can show *"backup for npub1abc…, made on 25 Jun 2026"* before asking for the passphrase. The nsec stays sealed inside the body. The header is authenticated as AEAD additional data — tampering with the header invalidates the GCM tag.

---

## What's inside `encrypted_body`

Every Isar collection that holds user-meaningful state. A single top-level JSON object, gzipped before encryption.

| Section | Source collection / store | Why it's in |
|---|---|---|
| `identity` | `UserKeyModel` + flutter_secure_storage | nsec + npub |
| `profile` | `ProfileModel` (own row) | Kind-0 cache so name/avatar load instantly |
| `notes` | `NoteModel` — all kinds (1, 14, 15, 42, 9023) where pubkey == self **OR** referenced by something owned | Own notes, replies, DM plaintext, group messages, private-group messages |
| `drafts` | `NoteModel` draft rows (Kind 31234) | Local-only drafts that were never published |
| `saved_notes` | `SavedNoteModel` | Bookmark pointers |
| `followed_users` | `FollowedUserModel` | Drives Vishnu `authors` filter on restore |
| `followed_notes` | `FollowedNoteModel` | Per-note graph subscriptions |
| `public_groups` | `GroupModel` | Group list — unread state lives in `unread_state` below, not per-model |
| `private_groups` | `PrivateGroupModel` + `PrivateGroupJoinRequestModel` + MLS group export | Membership + ratchet (caveat below) |
| `dms` | `DmConversationModel` | Conversation list. Actual messages already covered by `notes` (Kind 14) |
| `unread_state` | `UnreadNoteModel` (unified across feed/group/DM) | Read-position resume on restore |
| `shiv` | `ShivConversationModel` + `ShivMessageModel` | Full AI chat history with branching tree |
| `memory` | `MemoryNodeModel` | GraphRAG memory summaries |
| `media_refs` | `MediaCacheModel` (sha + url only, no blobs) | Lets restore know what was on disk; blobs re-fetch from Blossom by SHA on first view |
| `settings` | `AppSettingsModel` + `AIModelSelectionModel` | UI prefs + last-selected AI model name (file itself re-downloads) |
| `relays` | `RelayModel` | Custom relay list |
| `event_queue` | `EventQueueModel` — only `pending` rows | Anything tried offline that never reached the relay |
| `blocked_users` | `BlockedUserModel` | Mute list |
| `reports` | `ReportModel` | Own moderation history |

**Deliberately NOT included:**

- AI model files (`.task` / `.litertlm`) — multi-GB; only the *selected model name* is saved, user re-downloads on first Shiv open
- Local media blobs (cached images / video) — fetched on demand from Blossom by SHA-256; nothing lost
- Embedding vectors (`tostore`) — regenerable from notes; saves several MB
- Isar internal indexes — Isar rebuilds them on insert

---

## Export flow (Settings → Export Backup)

1. Confirmation sheet: *"Choose a strong passphrase. Anyone with this file and this passphrase can become you."* — two passphrase fields + warning checkbox.
2. Background isolate serialises each collection above into JSON.
3. gzip → AES-256-GCM with PBKDF2-derived key → write header + sealed body.
4. `file_picker.saveFile()` → user picks destination (Files / Drive / iCloud / SD card).
5. Success sheet shows the file path + a "Test restore" link that opens the import flow against this exact file (verifies it actually decrypts) without committing the restore.

---

## Import flow (Welcome → Import Identity → "Restore from backup" link)

1. File picker → user picks `.uniun` file.
2. Read header → show *"Backup for npub1abc… made 25 Jun 2026 on UNIUN v1.3.0"*.
3. Passphrase prompt → decrypt body. Wrong passphrase → *"Couldn't decrypt — wrong passphrase?"* (constant-time check via GCM tag).
4. **Key compare logic**:
   - nsec field empty → autofill from file → *"Restore everything?"*
   - User pasted a key that matches → *"Same identity — restore all your data?"*
   - User pasted a key that **differs** → modal: *"Backup is for npub1abc… but you pasted npub1xyz…. Choose one:"* with three buttons: **Use backup's key**, **Use pasted key only (skip restore)**, **Cancel**.
5. Restore in a background isolate: open Isar, `writeTxn` once per collection, bulk-insert rows. Per-section progress sheet (it can be 10 MB+ of data).
6. After restore: bootstrap the Gateway (picks up `RelayModel` + `FollowedUserModel` and re-subscribes), then HomePage.

---

## Relay safety (the real risks)

1. **Kind 3 follow-list overwrite.** Kind 3 is a *replaceable* event keyed by `(pubkey, kind)`. Restoring an old Kind 3 and republishing would clobber newer follows from another device.
   - **Mitigation**: on restore, fetch the latest Kind 3 from the relay first, take the **union** with the backup's follow list (newest `created_at` wins per author), write the merged result to `EventQueueModel`.

2. **MLS ratchet fork** (private channels). Restoring an old ratchet on a new device while the old device still has the live one forks the group — both devices keep deriving keys from the same point and integrity breaks.
   - **Mitigation**: use openmls 1.3's `Group.export()` / `Group.import()`; on restore, immediately commit a `self-update` to fast-forward and prove liveness. If import fails for a given group (version skew etc.), skip just that group with a banner *"Private channel 'X' needs to be rejoined"*; others still work.

3. **EventQueue replay.** Restoring `pending` rows onto a new device when the old device already sent them is safe — relay dedupes by event id. Restoring `sent` rows is pointless; skip them on serialise.

4. **Own notes re-broadcast.** None. Notes restore into Isar with `isSeen = true`. The Gateway only publishes from `EventQueueModel`, so restored notes never trigger duplicate broadcasts.

5. **DMs.** Even without a backup, the new device subscribes `{kinds:[1059], "#p":[me]}` and pulls the gift wraps; the backup just makes plaintext available instantly and survives the day the relay drops old 1059s to retention.

---

## Effort

| Slice | Days |
|---|---|
| File format + crypto + passphrase UX | 1 |
| Serialisers per collection (table above) | 1 |
| Restore + UI + Import screen wiring + key compare | 1 |
| MLS export/import + Kind 3 merge | 1 |
| Tests (round-trip per collection, wrong-passphrase, key-mismatch, MLS re-import) | 0.5 |

**~4–5 focused days for v1.** Single feature branch `feature/export-backup`, single PR.

---

## Out of scope (v2+)

- Auto-backup to user-controlled cloud (Drive, iCloud Files, S3) on a schedule
- Differential backups (only changed rows since last export)
- Multi-device live sync (a different problem; needs CRDT or a sync relay)
- Backup-of-backup (key escrow / Shamir split)
