# Proposal — cold fetch via shared Isar bus

Two surfaces, one architectural pattern:

1. **Cold note fetch** — opening a `nostr:note1...` reference / deep link / share embed for an event we haven't synced.
2. **Cold profile notes fetch** — opening another user's profile page when we don't follow them, so the feed subscription never pulled their notes.

Both hit the same wall: the UI sees an empty Isar query because the Gateway never asked the relay for that data. Same fix shape: Isar-as-bus + a new subscription provider.

---

## Section 1 — Cold note fetch

### Problem

When a user opens a note they haven't synced yet (deep-link, embedded share, mention reference, etc.), `NoteResolverRepository.resolveById` misses in Isar and returns `notFound`. The UI shows "Note not available" even though the note may exist on a relay we're already connected to.

### Constraint

UI runs in one isolate, Gateway in another. They never call each other directly — only Isar is shared. We don't want to break that boundary by introducing a request/response API or a fresh WebSocket per fetch.

### Proposal

Treat Isar as a bidirectional bus. UI writes a "please fetch this" row; Gateway watches the table and fires the REQ on the existing socket. No new transport, no new isolate messaging, same `watchLazy` pattern we already use for `EventQueueModel` and `FollowedNoteModel`.

### One new collection

```dart
@Collection
class PendingNoteFetchModel {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String eventId;
  late DateTime requestedAt;
  @Enumerated(EnumType.name) @Index()
  late PendingNoteFetchStatus status = PendingNoteFetchStatus.pending;
}

enum PendingNoteFetchStatus { pending, notFound }
```

Register in `isar_schemas.dart` alongside the other collections.

### One new subscription provider

`MissingNotesSubscription` (mirrors `ChannelsSubscription` exactly):

- `buildFilter`: read all `pending` rows; emit `{"ids": [...]}` over the existing socket.
- `supportsNip77 = false`, `wantsLiveTail = false` — one-shot lookups, not live subscriptions.
- `close` after EOSE handled by the synchronizer's normal flow.

Register in `GatewayOrchestrator._subscriptionProviders()`.

### Watcher hook

In `IsarWatcherHub`, add a `watchLazy` on `pendingNoteFetchModels` that calls `_registry.resubscribeAll('missing_notes')`. Same pattern as `followedNoteModels`.

### Inbound handler hook

In `kind1_note_handler` and `kind42_handler`, inside the existing `writeTxn`:

```dart
final pending = await isar.pendingNoteFetchModels
    .where().eventIdEqualTo(eventId).findFirst();
if (pending != null) await isar.pendingNoteFetchModels.delete(pending.id);
```

Closes the loop — the moment the relay returns the event, the pending row is gone.

### Cleanup ticker

A 5-second timer in `GatewayOrchestrator`:

- Pending rows older than 10 s → `status = notFound`.
- `notFound` rows older than 60 s → deleted.

Gives the UI a timeout signal and prevents retry-spam (60s cool-down on permanently-missing ids).

### Resolver fires the request

`NoteResolverRepository.enrichWithQuotes` (and `resolveById`), when an id is not found locally, calls `MissingNoteFetchRepository.request(id)`. The repo's `request` is idempotent — skips if a pending row exists, skips if a `notFound` row is younger than the cool-down.

Every read path (feed, thread, channel, DM, saved) automatically triggers the fetch. No per-bloc wiring.

### UI

`EmbeddedNoteCard` (and `ThreadPage`) with `note == null`:

- Render "Loading note…" with a spinner.
- Parent rebuilds when `noteModels` changes — the Isar watcher already exists.
- After 10 s, the orchestrator flips status to `notFound`; UI can read that to switch to "Note not available". (Optional v2: have the resolver populate a `quoteFetchStatus` field on the entity so the renderer knows whether to keep spinning or give up.)

### Flow diagrams

#### A. Internal share publish — sender side

```
┌──────────────────────────────────────────────────────────────────────┐
│ Sender device                                                        │
│                                                                      │
│   NoteCard.shareBtn ──▶ ShareSheetPage                               │
│                              │                                       │
│                              ▼ pick destination                      │
│                       ShareRepositoryImpl                            │
│                              │                                       │
│         ┌────────────────────┼────────────────────┐                  │
│         ▼                    ▼                    ▼                  │
│  PublishNoteUseCase  CreateChannelMsgUC  SendDmUseCase / PrivCh      │
│         │                    │                    │                  │
│         ▼                    ▼                    ▼                  │
│   Event.from()         Event.from()        encrypt(envelope)         │
│   tags: [p, q, k]      tags: [e root,      tags inside encrypted     │
│   content: "<comment>" e mention, p, q, k] payload                   │
│         │                    │                    │                  │
│         └────────────────────┼────────────────────┘                  │
│                              ▼                                       │
│                  Save NoteModel locally (Isar)                       │
│                  Enqueue in EventQueueModel (Isar)                   │
│                              │                                       │
└──────────────────────────────┼───────────────────────────────────────┘
                               │ Isar.watchLazy fires
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Gateway isolate (same device)                                        │
│                                                                      │
│   WebSocketService ─── ["EVENT", {…signed event with q tag…}] ──▶    │
└──────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
                          ┌──────────┐
                          │  Relay   │
                          └──────────┘
```

#### B. Receiver side — hot path (you follow the quoted-note's author)

```
                          ┌──────────┐
                          │  Relay   │
                          └──────────┘
                               │ pushes ["EVENT", {q-tag-share}]
                               │       AND  ["EVENT", {original note}]
                               │       (both already in our main sub
                               │        because we follow both authors)
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Receiver Gateway isolate                                             │
│                                                                      │
│   kind1_note_handler.handle(event)                                   │
│      ├── parse q-tag from event.tags  → model.quoteEventId = "abc…"  │
│      └── isar.noteModels.put(model)                                  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                               │ Isar fires noteModels.watchLazy
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Receiver UI isolate                                                  │
│                                                                      │
│   FeedRepository._toEntities() runs                                  │
│      ├── m.toDomain()  → NoteEntity(quoteEventId: "abc…")            │
│      └── resolver.enrichWithQuotes([entity])                         │
│             │                                                        │
│             ▼ one batched query                                      │
│           SELECT * FROM noteModels WHERE id IN ("abc…")              │
│             │                                                        │
│             ▼ HIT (we have it because we follow the author)          │
│         entity.quotedNote = NoteEntity(…)                            │
│                                                                      │
│   NoteCard renders                                                   │
│      ├── note.content  → "look at this"                              │
│      └── EmbeddedNoteCard(note: note.quotedNote)  ← renders fully    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

No fetch round-trip. Renders on first paint.

#### C. Receiver side — cold path (this proposal)

```
                          ┌──────────┐
                          │  Relay   │
                          └──────────┘
                               │ pushes ["EVENT", {q-tag-share}]
                               │       (we follow sender, but NOT
                               │        the quoted-note's author)
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Receiver Gateway isolate                                             │
│                                                                      │
│   kind1_note_handler ──▶ Isar (NoteModel with quoteEventId)          │
└──────────────────────────────────────────────────────────────────────┘
                               │ noteModels.watchLazy fires
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Receiver UI isolate                                                  │
│                                                                      │
│   FeedRepository._toEntities()                                       │
│      └── resolver.enrichWithQuotes([entity])                         │
│             │                                                        │
│             ▼ batched query MISS                                     │
│           quotedNote = null                                          │
│             │                                                        │
│             ▼ side effect: write a request row                       │
│           PendingNoteFetchModel { eventId: "abc…", status: pending } │
│                                                                      │
│   NoteCard renders                                                   │
│      └── EmbeddedNoteCard(note: null)  ← spinner + "Loading note…"   │
└──────────────────────────────────────────────────────────────────────┘
                               │ Isar fires pendingNoteFetch.watchLazy
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Gateway isolate (same device)                                        │
│                                                                      │
│   MissingNotesSubscription.buildFilter()                             │
│      └── REQ {"ids": ["abc…"]} on the existing socket                │
└──────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
                          ┌──────────┐
                          │  Relay   │
                          └──────────┘
                               │ returns ["EVENT", {abc…}]
                               │ then    ["EOSE", …]
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Gateway: kind1_note_handler.handle                                   │
│   writeTxn:                                                          │
│      ├── isar.noteModels.put(abc…)                                   │
│      └── delete the matching PendingNoteFetchModel row               │
└──────────────────────────────────────────────────────────────────────┘
                               │ noteModels.watchLazy fires
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ UI: resolver re-runs, entity now has quotedNote populated            │
│   EmbeddedNoteCard swaps from "Loading…" → real content              │
└──────────────────────────────────────────────────────────────────────┘
```

End-to-end latency for the cold fetch: typically 200 ms – 2 s on the same persistent socket.

#### Scenario summary

| Scenario | Path | Time to render |
|---|---|---|
| You follow both the share's author AND the quoted note's author | Hot — Isar hit on first paint | Instant |
| You follow the share's author but NOT the quoted note's author | Cold — pending row → REQ → EOSE → re-render | ~200 ms – 2 s |
| Quoted note doesn't exist on any relay you're connected to | Cold → 10 s timeout → flip to `notFound` | 10 s, then "Not available" |
| Quoted note is encrypted (DM / private channel), you're not a member | Relay returns nothing matching ids → same as previous | 10 s, then "Not available" |

### Why this is sound

- **NIP-01 compliant.** Multiple ids per REQ is part of the filter spec. EOSE always fires, even with zero matches. Reusing one socket per relay with multiplexed `subscription_id`s is the official recommendation.
- **Isar multi-isolate is officially supported.** Two isolates can open the same DB; `watchLazy` fires across isolates when one writes and the other watches. (Same mechanism the Gateway already uses for `EventQueueModel`.)
- **Convention-matching.** Same shape as the followed-notes / channel-meta / private-channel-meta subscription providers — none of which are novel.

### What changes

| File | Change |
|---|---|
| `lib/data/models/pending_note_fetch_model.dart` | New (~25 lines) |
| `lib/data/datasources/isar_schemas.dart` | +1 entry |
| `lib/domain/repositories/missing_note_fetch_repository.dart` | New interface (~10 lines) |
| `lib/data/repositories/missing_note_fetch_repository_impl.dart` | New (~35 lines, includes 60s cool-down) |
| `lib/domain/usecases/missing_note_fetch_usecases.dart` | New `RequestMissingNoteUseCase` (~8 lines) |
| `lib/gateway/subscriptions/providers/missing_notes_subscription.dart` | New provider (~35 lines) |
| `lib/gateway/orchestrator/gateway_orchestrator.dart` | Register provider + cleanup ticker (~30 lines) |
| `lib/gateway/watchers/isar_watcher_hub.dart` | +1 `watchLazy` (~6 lines) |
| `lib/gateway/inbound/handlers/kind1_note_handler.dart` | +5 lines (delete-on-persist) |
| `lib/gateway/inbound/handlers/kind42_handler.dart` | +5 lines (delete-on-persist) |
| `lib/data/repositories/note_resolver_repository_impl.dart` | Inject fetch repo + `unawaited(request(id))` on miss |
| `lib/common/widgets/note_card/embedded_note_card.dart` | Placeholder copy: "Loading note…" + spinner |

~250 lines net. No new external dependency, no new transport, no widget-side DB calls.

### What it does NOT solve (and shouldn't try to)

- **Encrypted notes (DM / private channel) we are not a recipient of.** The relay returns the encrypted envelope; we can't decrypt. EmbeddedNoteCard correctly shows "Note not available" — that's the right outcome.
- **Notes the relay never had.** EOSE returns with nothing, the 10s timeout flips status to `notFound`, UI shows "Note not available". No retry until cool-down expires.
- **Cross-relay sync of unknown ids.** We only ask the relays we're already connected to. If the note only exists on a relay the user hasn't added, we won't find it. NIP-65 (relay hints) is the eventual fix; out of scope here.

### Open questions

1. **Cool-down window.** 60 s feels right for a permanently-missing id, but if a relay just had a transient hiccup, it's a 60s wait before we retry. Acceptable trade-off?
2. **UI placeholder.** Show "Loading…" indefinitely vs. flip to "Not available" after 10 s? Current proposal: flip via the `notFound` status reaching the entity. Requires either (a) a `quoteFetchStatus` field on `NoteEntity` populated by the resolver, or (b) the bloc watches `pendingNoteFetchModels` separately. Option (a) is cleaner.
3. **Batch size.** No upper limit on `ids` array in one REQ — fine for now, but at very high scrollback we might want a max of ~50 ids per REQ. Defer until measured.

### Status

Branched as `share` (full implementation, ~7 files + 250 lines). Ready to merge once we agree on the answers to the three open questions above. Current `main` doesn't carry any of this; the external-share UI was reverted from the share-sheet so we can land the proposal cleanly later.

---

## Section 2 — Cold profile notes fetch

### Problem

Open another user's profile (via `UserProfilePage`) — the page reads from Isar via `NoteRepository.getOwnNotes(pubkeyHex)`. For non-followed users, Isar is empty and the page shows "No notes yet" even though the relay holds their entire history.

### Why it's empty

`FeedNotesSubscription` (the Gateway's main Kind 1 REQ) filters by author allow-list:

```json
{"kinds": [1], "authors": ["<own>", "<followed_1>", "<followed_2>", …]}
```

We deliberately don't subscribe to the firehose — otherwise every UNIUN install would receive every Kind 1 on the relay. Non-followed users' notes are simply never pulled into Isar.

### Proposal — same shape as Section 1

A second pending table, watched by a second subscription provider. The only difference is the key is `pubkey`, not `eventId`, and the subscription stays open for the lifetime of the profile page rather than being one-shot.

### One new collection

```dart
@Collection
class ProfileNotesFetchModel {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  late String pubkeyHex;
  late DateTime requestedAt;
}
```

No `status` enum — the row's existence IS the request. UI deletes the row when the profile page closes; Gateway closes the REQ.

### One new subscription provider

`ProfileNotesSubscription`:

- `buildFilter`: read all rows, emit `{"kinds": [1], "authors": [...pubkeys], "limit": 50}` over the existing socket.
- `wantsLiveTail = true` — keep the subscription open while the profile is on screen so new notes from that user arrive in real time.
- `close` when the row is deleted (provider re-runs with empty filter → triggers CLOSE).

### Watcher hook

`IsarWatcherHub` adds a `watchLazy` on `profileNotesFetchModels` that calls `_registry.resubscribeAll('profile_notes')`.

### Lifecycle

UI side (`UserProfilePage` bloc / cubit):
1. On `initState` (or `BlocProvider.create`) — write a row for the viewed pubkey via `RequestProfileNotesUseCase`.
2. On `dispose` — delete the row via `ReleaseProfileNotesUseCase`.

Optimisation: skip the write if `FollowedUserModel.contains(pubkey)` — we're already getting their notes via the main feed subscription.

### Inbound: no new handler needed

`kind1_note_handler` already persists every Kind 1 it sees. Profile page reads via `NoteRepository.getOwnNotes(pubkey)`, which is Isar-reactive (watches `noteModels`). Notes appear as they arrive.

### What changes

| File | Change |
|---|---|
| `lib/data/models/profile_notes_fetch_model.dart` | New (~15 lines) |
| `lib/data/datasources/isar_schemas.dart` | +1 entry |
| `lib/domain/repositories/profile_notes_fetch_repository.dart` | New interface (~10 lines) |
| `lib/data/repositories/profile_notes_fetch_repository_impl.dart` | New (~30 lines, includes "already-followed" skip) |
| `lib/domain/usecases/profile_notes_fetch_usecases.dart` | `Request` + `Release` use cases (~15 lines) |
| `lib/gateway/subscriptions/providers/profile_notes_subscription.dart` | New provider (~25 lines) |
| `lib/gateway/orchestrator/gateway_orchestrator.dart` | Register provider |
| `lib/gateway/watchers/isar_watcher_hub.dart` | +1 `watchLazy` (~6 lines) |
| `lib/features/profile/pages/user_profile_page.dart` | Bloc/cubit calls `Request` on open + `Release` on dispose |

~150 lines net. Smaller than Section 1 — no timeout/cool-down logic, no inbound delete-on-persist (the subscription naturally streams while open).

### Why this is sound

- **NIP-01 compliant** — `authors` array is a standard filter attribute, no different from the main feed sub.
- **Bounded fan-out** — open profiles = open subscriptions. Realistically a user has 1-2 profile pages open at a time. Each adds one author to one REQ; relay load is negligible.
- **Already-followed short-circuit** — avoids duplicate subscriptions for users you already follow (their notes flow via the main feed sub).

### Open questions

1. **`limit` default.** 50 most recent notes per profile. Reasonable for a first view; pagination (`since`/`until`) is a follow-up.
2. **Profile retention.** When the user closes the profile page, do we delete the fetched notes from Isar (privacy/storage) or keep them around for the next open? Currently `CleanupManager` evicts non-saved Kind 1 notes after 7 days — same rule applies to profile-viewed notes, no special handling needed.
3. **Multiple open profiles.** If the user has two profile pages in the back stack and closes one, we need to keep the other's row alive. The `Release` use case should only delete the row for the closing page, not every row. Trivial — just key by pubkey.

### Status

Not yet implemented. Same convention as Section 1; can ship in the same PR or stand alone.
