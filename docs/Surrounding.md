# UNIUN Surrounding Feed — Design

The **Surrounding feed** ("📍 Nearby") is UNIUN's offline **discovery** surface: public notes from
*strangers* in radio / Wi-Fi range, with **no shared identity, no relay, no internet**. It rides the
exact same transports, negotiator, and gossip router as same-identity multi-device sync — but where
sync is *trusted, private, and permanent*, Surrounding is deliberately its mirror image:
**untrusted, public, ephemeral, and multi-hop**.

> This document is the deep-dive on the *stranger* half of the mesh. For the transport seam,
> handshake, and the *same-identity* sync half, see [MESH.md](MESH.md) — Surrounding is summarized
> there in §8 and §11 and expanded here.

---

## 1. What it is (user-facing)

When you enable **Nearby** (Settings → the mesh opt-in card), your device starts advertising and
discovering peers over LAN/Wi-Fi and BLE. Two behaviours are possible on any connection, chosen
automatically by a cryptographic handshake ([MESH.md §6](MESH.md#6-identity-handshake-identity_proofdart)):

- peer proves the **same** pubkey as you → **same-identity sync** (all your content reconciles);
- peer proves a **different** pubkey → **Surrounding** (you exchange *public* notes as strangers).

Received stranger notes land in an ephemeral **"📍 Nearby"** feed that:

- shows the standard `NoteCard` (with the author's name/avatar if their profile came through),
- is **evicted daily** — a nearby note disappears one day after you first saw it,
- tracks **unread** like the main feed (a "jump to first unread" + count),
- can be **saved** — bookmarking a nearby note promotes it into your forever-retained saved notes,
  out of the ephemeral cache's reach.

Notes also **gossip multi-hop**: a stranger's note reaches you even if they're not in direct range,
relayed hop-by-hop through intermediate devices (TTL-bounded).

Default **off** for privacy and battery.

---

## 2. Trust model — the mirror image of sync

| Aspect | Same-identity sync | **Surrounding** |
|---|---|---|
| Peer identity | your own pubkey (proven) | a stranger's pubkey (proven, but not trusted) |
| Channel | **AEAD-encrypted** (ChaCha20-Poly1305) | **plaintext** (content is public by design) |
| Payload | decrypted private rows (notes, DMs, follows…) | only **public** Nostr events (kind 0 + kind 1) |
| Verification | channel *is* the auth (trusted) | **every event** re-verified: `Event.isValid()` (id + Schnorr) |
| Retention | permanent (reconciled) | **ephemeral** — evicted 1 day after first contact |
| Reach | direct peer only | **multi-hop gossip** (TTL 7) |

Because strangers are untrusted, the inbound path is an adversarial gate: everything is
signature-checked, rate-limited, and filtered before it touches local storage. Because the content
is inherently public, the channel is *not* encrypted (encrypting a public note would only hide a
value the author intends everyone to read).

---

## 3. Where it lives

```
lib/features/mesh/surrounding/
├── broadcast_event.dart        canonical event reconstruction (own/saved → signed wire event)
├── broadcast_set_builder.dart  builds what THIS device offers a stranger (capped, cursored)
├── surrounding_inbound.dart    the untrusted inbound gate (verify + store)
├── surrounding_exchange.dart   per-peer delta broadcast (paced)
└── surrounding_cleanup.dart    daily eviction (keyed on firstSeenAt)

lib/features/mesh/router/mesh_router.dart          multi-hop gossip (dedupe + forward)
lib/data/models/surrounding_note_model.dart        ephemeral cache (@Name('SurroundingNote'))
lib/data/datasources/surrounding_read_state_store.dart   unread watermark (SharedPreferences)
lib/domain/repositories/surrounding_note_repository.dart (+ impl)   UI read / page / mark-read
lib/features/surrounding/
├── cubit/surrounding_cubit.dart (+ surrounding_state.dart)   live feed + unread
└── pages/surrounding_feed_page.dart                          "📍 Nearby" (NoteCard)
lib/features/mesh/mesh_constants.dart              all tuning knobs (caps, pacing, retention)
```

The exchange runs **inside `MeshEngineHost`** (Android headless engine / Apple inline), exactly like
the sync engines. The presentation layer (`lib/features/surrounding/`) reads only from Isar.

---

## 4. Outbound — the broadcast set (`broadcast_set_builder.dart`)

`build()` assembles what *this* device offers a stranger — newest-first and capped:

- own **kind-1 notes** (`kMaxOwnBroadcastNotes = 10`),
- **saved** non-channel notes (`kMaxSavedBroadcastNotes = 10`) — content this user vouched for,
- own **kind-0 profile**, re-signed from `ProfileModel` with a **stable `created_at = updatedAt`** so
  re-ingest on the peer is idempotent (last-write-wins by pubkey, never a growing pile).

The saved-note slice is cursored by **`savedAt`** (not row id), so "what's new since last broadcast"
is a monotonic time delta that survives across sessions and row-id churn.

### Canonical reconstruction (`broadcast_event.dart`)

Strangers re-verify every event, so for our *own* outbound notes to pass `Event.isValid()` on the
peer, `buildBroadcastEvent` must rebuild the event's tags in the **exact canonical order** used by
`EventQueueModel.toSerializedRelayMessage` (e:root → e:reply → e:mention → p → t → q). A saved note
that some other client signed in a *different* tag order won't re-serialize to the same id, so it is
**dropped before send** (safe — just not propagated). Net effect: your **own** notes always
propagate; **saved** notes propagate whenever they're reconstructable.

> This is why the tag-order discipline documented in `event_queue_model.dart` matters beyond the
> relay — the surrounding broadcaster reproduces the same canonical serialization.

---

## 5. Inbound — the untrusted gate (`surrounding_inbound.dart`)

`ingest(json)` runs these checks **in order**, cheapest-and-most-selective first:

1. **parse** — malformed JSON → drop; **own pubkey → drop** (never ingest our own echo);
2. **kind guard** — only kind 0 (profile) or kind 1 (`kNoteKind`) proceed;
3. **flood guard** — a rolling `kSurroundingMaxNotesPerSecond` (**2/s**) cap, checked *before* the
   Schnorr verify so a note flood can't burn CPU on signatures we'll discard. **Applies to kind-1
   only**; kind-0 profiles are exempt (idempotent LWW by pubkey);
4. **`Event.isValid()`** — recomputed id + Schnorr signature (forgeries dropped);
5. **store** — in a `writeTxn` that re-checks blocked author / tombstoned / locally-removed id:
   - kind 0 → `ProfileModel` upsert (name/avatar so `NoteCard` renders the author),
   - kind 1 → `SurroundingNoteModel` (see §6).

`ingest` returns `true` for "valid public event worth relaying" — **independent of local storage**.
So a valid note from a *blocked* author still **relays** onward (blocking is a local-view choice)
but is **not stored** in this device's feed.

---

## 6. Ephemeral cache + eviction (`SurroundingNoteModel`)

`SurroundingNoteModel` (`@Name('SurroundingNote')`, unique-replace on `eventId`) is a **throwaway
cache** — evicting it is **not** a `deleted` field and does not violate Feed Freedom. It carries two
indexed timestamps with distinct jobs:

- **`firstSeenAt`** — set **once**, the first time this id is stored, and **never moved**. Eviction
  keys off it: `SurroundingCleanup.evictFirstSeenBefore(now − kSurroundingRetention)` (**1 day**)
  runs on startup and every `kSurroundingCleanupInterval` (**1 h**). Because it's immutable, a note
  that keeps getting re-broadcast **can't extend its own retention** — it still ages out one day
  after first contact.
- **`receivedAt`** — bumped on **every** (re-)receipt. It drives feed ordering, paging
  (`getBefore` / `getAfter`, `kSurroundingPageSize = 10`), and the unread watermark.

### Read state / unread (`SurroundingReadStateStore`)

A single **`receivedAt` watermark** is persisted in SharedPreferences — a *timestamp*, deliberately
**not** a `lastReadEventId` pointer (an id could reference an already-evicted note; a timestamp
survives eviction). A surrounding note is **unread** iff `receivedAt > watermark`; `markReadUpTo(ts)`
only ever advances the watermark. `SurroundingCubit` watches `surroundingNoteModels` for the live
feed and exposes the unread count + "jump to first unread", mirroring the feed / channel / DM read
model.

### Rendering

`SurroundingNoteModel.toDomain()` produces a plain `NoteEntity`; the **"📍 Nearby" source label is
localized at the presentation layer** (`SurroundingFeedPage`), never stored in the data layer. The
standard `NoteCard` renders it. **Saving** a nearby note promotes it into forever-retained saved
notes (out of the ephemeral cache's reach).

---

## 7. Delta + pacing (`surrounding_exchange.dart`)

One `SurroundingExchange` is kept **per peer**:

- the first `broadcast()` sends the full capped set;
- later `broadcast()`s send only ids **not** in `_sentIds` (the delta);
- sends are paced `kSurroundingSendInterval` (**600 ms**) apart, matching the receiver's 2/s guard so
  a well-behaved sender never trips its own peer's flood cap.

When local content changes, `MeshEngineHost` watches `noteModels` + `savedNoteModels` and (debounced)
re-broadcasts the **delta** to every stranger peer — so a freshly-written note reaches nearby devices
in ~2 s without an app restart.

---

## 8. Multi-hop gossip (`router/mesh_router.dart`)

`MeshRouter` turns the point-to-point exchange into a **flood** so a public note hops beyond direct
range while each event is processed and relayed **at most once**. For an inbound `EventMessage`:

1. **dedupe** by event id against a bounded FIFO seen-set (`kMeshRouterSeenCap = 8192`) — the
   loop / amplification guard;
2. **verify + store** via the link's ingest (`SurroundingInbound.ingest`);
3. if it was a valid public event **and** its TTL isn't exhausted, **forward** to every *other*
   stranger / mesh peer with `ttl − 1`.

The origin broadcast starts at `kMeshMaxTtl = 7`; a receiver at ttl 0 stores but does not forward
(bounding the flood). **Same-identity peers are never gossiped to** (their content rides the trusted
sync), and the source is never echoed back.

```mermaid
sequenceDiagram
  participant A as Device A (stranger)
  participant B as Device B
  participant C as Device C (out of A's range)
  Note over A: BroadcastSetBuilder.build() = own kind-1 ∪ saved (non-channel) ∪ own kind-0
  A->>B: EventMessage(event, ttl=7)   (delta vs _sentIds, paced 600ms)
  Note over B: MeshRouter.onEvent → dedupe(id) → SurroundingInbound.ingest
  Note over B: Event.isValid()? own/blocked/tombstoned? kind 0→Profile, kind 1→SurroundingNote
  B->>C: forward EventMessage(event, ttl=6)   (to every OTHER peer)
  Note over C: same gate; multi-hop reach beyond A's radio range
  Note over B: SurroundingCubit watches surroundingNoteModels → live "📍 Nearby" feed
```

---

## 9. Tuning knobs (`mesh_constants.dart`)

| Constant | Value | Role |
|---|---|---|
| `kMeshMaxTtl` | 7 | origin gossip TTL (max hops) |
| `kMeshRouterSeenCap` | 8192 | FIFO dedupe window for the gossip relay |
| `kMaxOwnBroadcastNotes` | 10 | cap on own kind-1 notes in the broadcast set |
| `kMaxSavedBroadcastNotes` | 10 | cap on saved non-channel notes in the broadcast set |
| `kSurroundingMaxNotesPerSecond` | 2 | inbound kind-1 flood cap (pre-verify) |
| `kSurroundingSendInterval` | 600 ms | outbound pacing (matches the receiver's cap) |
| `kSurroundingPageSize` | 10 | feed paging window |
| `kSurroundingRetention` | 1 day | eviction age (on `firstSeenAt`) |
| `kSurroundingCleanupInterval` | 1 h | how often the eviction sweep runs |

---

## 10. Security model & known limitations

| Path | Trust | Check |
|---|---|---|
| Handshake | — | mutual signed-nonce; proof must bind *our* nonce to the *claimed* pubkey |
| Surrounding inbound | untrusted | `Event.isValid()` (id + Schnorr) + not-own + blocked + tombstone |
| Gossip relay | untrusted | dedupe by id; only valid public events forwarded, TTL-bounded |
| Advertisement | — | **no pubkey** in mDNS TXT or BLE advertisement; identity only after connect |

**Known limitations (not hardened in this phase):**

- **kind-0 flood.** The per-second cap gates only kind-1; a peer could stream many *distinct-pubkey*
  kind-0 profiles, each reaching the Schnorr verify + a `ProfileModel` upsert. In practice a stranger
  only legitimately broadcasts **one** profile (their own), so this is low-severity; a kind-0 rate
  limit is a tracked follow-up.
- **Foreign saved-note authors' names** can't be verifiably broadcast to strangers (only our *own*
  profile re-signs), so a relayed saved note may render with a raw pubkey until the viewer fetches
  that profile from a relay when back online. (Same-identity peers *do* exchange kind-0 via the
  `publicEvent` sync scope.)
- **Transport caveats** are shared with sync: mobile-hotspot AP isolation breaks LAN (BLE still
  works); iOS LAN is foreground-only. See [MESH.md §9–10](MESH.md#9-lan-transport-transportlan).

---

## 11. Relationship to same-identity sync

Surrounding and sync are two behaviours over **one** stack. They share the transport seam
(`MeshLink`), the negotiator, the channel, and the gossip router; the handshake picks which runs per
peer. The deliberate contrasts:

| | Same-identity sync ([MESH.md §7](MESH.md#7-same-identity-sync-sync)) | Surrounding (this doc) |
|---|---|---|
| Reconciliation | NIP-77 negentropy over signed events (all scopes) | one-directional broadcast + multi-hop gossip |
| Data | full private state (notes, DMs, follows, blocks, profiles) | public kind 0 + kind 1 only |
| Storage | permanent Isar rows | ephemeral `SurroundingNote` cache (1-day eviction) |
| Encryption | AEAD channel seal | none (public content) |
| UI | your normal feed / DMs / channels | the "📍 Nearby" feed |

---

## 12. Testing

Covered in `test/surrounding/` (+ shared harness in `test/mesh/`):

- **broadcast set** — own+saved capping, `savedAt` cursor delta, own-profile stable `created_at`;
- **canonical reconstruction** — own notes re-serialize to a valid id; wrong-tag-order saved notes
  are dropped before send;
- **inbound gate** — malformed / own / wrong-kind dropped; 2/s flood cap (kind-1 only); forgery
  (bad sig) dropped; blocked-author relays-but-not-stored; tombstoned skipped;
- **cache & read state** — `firstSeenAt` immutable (retention can't be extended), `receivedAt`
  bumps paging/unread, timestamp watermark survives eviction;
- **eviction** — `evictFirstSeenBefore` removes only aged rows;
- **gossip router** — dedupe / TTL decrement / no-echo-to-source / same-identity-skip;
- **integration** — a verified note + author profile propagates across two real Isar peers;
  forgeries dropped; own echo skipped.

Run: `flutter test test/surrounding/ test/mesh/`.
