# Proposal — cold note fetch via shared Isar bus

## Problem

When a user opens a note they haven't synced yet (deep-link, embedded share, mention reference, etc.), `NoteResolverRepository.resolveById` misses in Isar and returns `notFound`. The UI shows "Note not available" even though the note may exist on a relay we're already connected to.

## Constraint

UI runs in one isolate, Gateway in another. They never call each other directly — only Isar is shared. We don't want to break that boundary by introducing a request/response API or a fresh WebSocket per fetch.

## Proposal

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

## Why this is sound

- **NIP-01 compliant.** Multiple ids per REQ is part of the filter spec. EOSE always fires, even with zero matches. Reusing one socket per relay with multiplexed `subscription_id`s is the official recommendation.
- **Isar multi-isolate is officially supported.** Two isolates can open the same DB; `watchLazy` fires across isolates when one writes and the other watches. (Same mechanism the Gateway already uses for `EventQueueModel`.)
- **Convention-matching.** Same shape as the followed-notes / channel-meta / private-channel-meta subscription providers — none of which are novel.

## What changes

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

## What it does NOT solve (and shouldn't try to)

- **Encrypted notes (DM / private channel) we are not a recipient of.** The relay returns the encrypted envelope; we can't decrypt. EmbeddedNoteCard correctly shows "Note not available" — that's the right outcome.
- **Notes the relay never had.** EOSE returns with nothing, the 10s timeout flips status to `notFound`, UI shows "Note not available". No retry until cool-down expires.
- **Cross-relay sync of unknown ids.** We only ask the relays we're already connected to. If the note only exists on a relay the user hasn't added, we won't find it. NIP-65 (relay hints) is the eventual fix; out of scope here.

## Open questions for the team

1. **Cool-down window.** 60 s feels right for a permanently-missing id, but if a relay just had a transient hiccup, it's a 60s wait before we retry. Acceptable trade-off?
2. **UI placeholder.** Show "Loading…" indefinitely vs. flip to "Not available" after 10 s? Current proposal: flip via the `notFound` status reaching the entity. Requires either (a) a `quoteFetchStatus` field on `NoteEntity` populated by the resolver, or (b) the bloc watches `pendingNoteFetchModels` separately. Option (a) is cleaner.
3. **Batch size.** No upper limit on `ids` array in one REQ — fine for now, but at very high scrollback we might want a max of ~50 ids per REQ. Defer until measured.

## Status

Branched as `share` (full implementation, ~7 files + 250 lines). Ready to merge once we agree on the answers to the three open questions above. Current `main` doesn't carry any of this; the external-share UI was reverted from the share-sheet so we can land the proposal cleanly later.
