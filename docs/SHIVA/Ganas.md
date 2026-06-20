# Ganas — User-Owned AI Agents on Top of Manas

> **Status**: Phase 2 (shipped foreground; background tick installed; background inference gated on `flutter_gemma_bg_isolate_test.dart`).
> **Lives in**: Shiv (the AI assistant tab).
> **Companion**: `docs/BRAHMA/Manas.md` (the knowledge bases Ganas consume).

A **Gana** ("गण" — a band, group, or attendant in Sanskrit) is a user-defined AI worker. The user gives it knowledge (one or more **Manases**), instructions (a **task prompt**), an **input** to watch, an **output** to publish to, and **triggers**. Once enabled, the Gana runs by itself — on-device — and publishes results as real Nostr events.

Ganas are **purely local config** — they never broadcast as Nostr events. Two devices with the same identity have independent Gana sets.

---

## Table of Contents

1. [Functional model](#1-functional-model)
2. [Three-isolate topology](#2-three-isolate-topology)
3. [Manas Context Loader](#3-manas-context-loader)
4. [Data model](#4-data-model)
5. [Domain layer](#5-domain-layer)
6. [Single-run lifecycle](#6-single-run-lifecycle)
7. [Inference bridge — does it block the UI?](#7-inference-bridge--does-it-block-the-ui)
8. [Background execution](#8-background-execution)
9. [Self-loop + safety guards](#9-self-loop--safety-guards)
10. [UI placement](#10-ui-placement)
11. [Folder structure](#11-folder-structure)
12. [Open follow-ups](#12-open-follow-ups)

---

## 1. Functional model

### 1.1 What a Gana has

| Field | Notes |
|---|---|
| `name` | required, ≤60 chars |
| `description` | optional |
| `manasIds` | **one or more** Manases — context is merged across all of them under a shared budget |
| `taskPrompt` | user-authored instructions injected into every prompt |
| `inputType` + `inputRefId` | input surface — `channel`, `privateChannel`, `dm`, `user`, `followedNote`, or `null` (standalone) |
| `outputType` + ref | destination — `feed`, `channel`, `privateChannel`, `dm` (exactly one is published per run) |
| `desiredModelId` | `null` ⇒ "use whichever model is active"; otherwise skip-on-mismatch |
| `triggerReactive` | fires within ~3s of a new note on the input surface |
| `triggerIntervalMinutes` | `Timer.periodic` clamped ≥5 min (≥30 min in background) |
| `enabled` | master switch (defaults to `false` — opt-in after review) |
| Cursor | `lastProcessedEventId`, `lastProcessedCreated`, `lastRunAt` |

### 1.2 The "Life Lessons Replier" example

```
User config:
  name:        "Life Lessons Replier"
  manases:     [Life Lessons]   (47 saved + own + draft notes)
  input:       Channel #daily-thoughts (joined)
  output:      Channel #daily-thoughts (same)
  trigger:     Reactive
  taskPrompt:  "When someone posts a question or reflection here, pick
                the most relevant note from my Manas and reply with a
                1-2 sentence paraphrase that adds value."

Run trace:
  1. Bob posts kind-42 in #daily-thoughts.
  2. Gateway writes it to noteModels.
  3. Engine's noteModels.watchLazy() fires; debounced 3s.
  4. Input filter selects Bob's message (created > cursor, not self,
     not in our own output history).
  5. Manas Context Loader packs 28 of 47 notes under the budget.
  6. Prompt assembled: task → INPUT (Bob's msg) → KNOWLEDGE (28 notes).
  7. Engine SendPort ──► main isolate inference server.
  8. Server: openChat → sendMessage → text reply.
  9. <NOOP> check: no. Body extracted.
 10. Engine writes GanaPendingOutputModel { body, ganaId, runId,
     outputType: channel, outputChannelId: #daily-thoughts }.
 11. Cursor advanced; GanaRunModel.succeeded logged.
 12. Main-isolate GanaOutputDispatcher watches the pending table,
     picks the row, calls CreateChannelMessageUseCase.
 13. Existing publish path (sign → EventQueueModel → gateway → relay).
 14. Dispatcher stamps outputEventId back on the GanaRun row.
 15. Bob sees the reply in #daily-thoughts within ~10s.
```

---

## 2. Three-isolate topology

This is the most important diagram in the doc.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          MAIN ISOLATE (UI)                                │
│                                                                          │
│  ShivHistoryDrawer ─► GanaListBloc ─► GetGanasUseCase ─► Isar (Gana*)    │
│  GanaFormPage      ─► GanaFormBloc ─► UpsertGanaUseCase                  │
│  GanaDetailPage    ─► GetGanaRunsUseCase                                 │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ GanaInferenceServer  (@lazySingleton, started by GanaBootstrap)    │ │
│  │   ◄── SendPort ◄── engine isolate                                  │ │
│  │   delegates to AIModelRunner.generateOneShot()                     │ │
│  │   which goes through LocalInferenceQueue.runLow                    │ │
│  │   ─► Shiv chat (runHigh) always preempts                           │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ GanaOutputDispatcher (@lazySingleton)                              │ │
│  │   watches ganaPendingOutputModels.watchLazy()                      │ │
│  │   ─► PublishNoteUseCase (feed)                                     │ │
│  │   ─► CreateChannelMessageUseCase (channel)                         │ │
│  │   ─► SendPrivateChannelMessageUsecase (NIP-29 / MLS)               │ │
│  │   ─► SendDmUseCase (NIP-17 gift-wrap)                              │ │
│  │   on success → stamps outputEventId on the matching GanaRun        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  HomePage (WidgetsBindingObserver)                                       │
│    AppLifecycleState.paused  ─► GanaBootstrap.scheduleBackground()       │
│    AppLifecycleState.resumed ─► GanaBootstrap.cancelBackground()         │
└──────────────────────────────────────────────────────────────────────────┘
                                  ▲       │
                                  │       │  Isar (shared DB on-disk)
                                  │       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                  GANA ENGINE ISOLATE  (long-lived background)             │
│                                                                          │
│  GanaEngine                                                              │
│   ├ noteModels.watchLazy()  ─► reactive Ganas (3s debounce)              │
│   ├ Timer.periodic(N min)   ─► interval Ganas                            │
│   ├ ganaModels.watchLazy()  ─► schedule rebuild (500ms debounce)         │
│   ├ Single-flight mutex     ─► one run at a time globally                │
│   │                                                                      │
│   └ One run:                                                             │
│      ┌─────────────────────────────────────────────────────────┐         │
│      │ 1. Self-output set loaded for guard                      │         │
│      │ 2. GanaInputFilter (per-type Isar query + cursor +       │         │
│      │    drop-self-pubkey + drop-self-outputs)                 │         │
│      │ 3. Reply ancestry (up to 2 hops)                         │         │
│      │ 4. ManasContextLoader.merge — union across all manasIds  │         │
│      │ 5. GanaPromptBuilder — task + INPUT + KNOWLEDGE + NOOP   │         │
│      │ 6. SendPort ─► main isolate GanaInferenceServer          │         │
│      │ 7. Reply (ok / skip / fail / cancelled)                  │         │
│      │ 8. Write GanaPendingOutputModel (engine never publishes) │         │
│      │ 9. Log GanaRunModel + advance cursor                     │         │
│      └─────────────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────────────────┘
                                  ▲       │
                                  │       │  Isar (shared)
                                  │       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│              WORKMANAGER ISOLATE  (ephemeral, OS-dispatched)              │
│                                                                          │
│  ganaWorkManagerDispatcher (top-level, @pragma vm:entry-point)           │
│   ├ Fires ~30 min after AppLifecycleState.paused                         │
│   ├ Opens own Isar at the shared path                                    │
│   └ Walks enabled interval Ganas                                         │
│       ─► v1: bumps lastRunAt on due ones (NO inference)                  │
│       ─► v2 (after bg-isolate test passes): real inference here          │
└──────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │  EventQueueModel rows from publish use cases
                                  ▼
                  GATEWAY ISOLATE (existing) ──► relay broadcast
```

Three isolates, **two of them long-lived** (main + engine), one ephemeral (workmanager fires only when the app is paused/killed).

---

## 3. Manas Context Loader

`lib/features/shiv/gana/engine/manas_context_loader.dart`

```
ManasContextLoader.merge({
  required Isar isar,
  required List<String> manasIds,
  required int budget,                  // tokens
}) async → List<PackedNote>

   1. For each manasId in manasIds:
        link rows = ManasNoteLinkModel where manasId == this
        add all noteIds to a Set (dedupes across manases)

   2. For each noteId in the union:
        resolve via SavedNoteRepository → noteModels → draftModels
        (first hit wins; produces PackedNote with source = saved | own | draft)

   3. Sort PackedNote list by `created` descending

   4. Pack newest-first under (budget * 4 chars/token * 0.85 safety margin)
      Skip oversize notes rather than truncate (truncation changes meaning)

   5. Return packed list
```

No vector retrieval in v1. Manases are small and curated by hand — the user already ranked them by adding the notes. Direct-pack is cheap, deterministic, and runs entirely in the engine isolate without an embedder. Scoped-vector retrieval (carrying `allowedNoteIds` through `VectorRepository`) is deferred.

---

## 4. Data model

Four Isar collections (three new, plus existing `ManasModel` / `ManasNoteLinkModel`).

```
┌──────────────────────────────┐  ┌──────────────────────────────┐
│ GanaModel                    │  │ GanaRunModel                 │
├──────────────────────────────┤  ├──────────────────────────────┤
│ Id  id                       │  │ Id  id                       │
│ String ganaId (uniq)         │  │ String runId (uniq)          │
│ String name                  │  │ String ganaId (idx)          │
│ String? description          │  │ DateTime startedAt (idx)     │
│ List<String> manasIds        │  │ GanaRunStatus status         │
│ String taskPrompt            │  │  (running|succeeded|         │
│ GanaInputType? inputType     │  │   skipped|failed)            │
│ String? inputRefId           │  │ GanaSkipReason? skipReason   │
│ GanaOutputType outputType    │  │  (noActiveModel|             │
│ String? outputChannelId      │  │   modelMismatch|             │
│ String? outputGroupId        │  │   noNewInput|modelSwapped|   │
│ int? outputDmConversationId  │  │   noopReturned)              │
│ String? desiredModelId       │  │ List<String> inputEventIds   │
│ bool triggerReactive         │  │ String? outputEventId        │
│ int? triggerIntervalMinutes  │  │ String? error                │
│ bool enabled                 │  └──────────────────────────────┘
│ String? lastProcessedEventId │
│ DateTime? lastProcessedCrtd  │  Retention: per-Gana 10 newest,
│ DateTime? lastRunAt          │  global cap 1000, pruned every
│ DateTime createdAt           │  6h by CleanupManager (Phase 3).
│ DateTime updatedAt           │
└──────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ GanaPendingOutputModel                                │
├──────────────────────────────────────────────────────┤
│ Id  id                                                │
│ String pendingId  (uniq)                              │
│ String ganaId  (idx)                                  │
│ String runId   (idx)         ──► stamps outputEventId │
│ String body                       on this GanaRun     │
│ GanaOutputType outputType                             │
│ String? outputChannelId                               │
│ String? outputGroupId                                 │
│ int? outputDmConversationId                           │
│ DateTime createdAt  (idx)                             │
│ int attempts                 retry capped at 3        │
│ String? lastError                                     │
└──────────────────────────────────────────────────────┘
       ▲ engine writes              ▼ main-isolate dispatcher
       │                            │ watches this table,
       │                            │ publishes, then deletes
       └───── pendingId is the      │
             handshake.             │
                                    ▼
                             [PublishNoteUseCase / etc]
```

All three schemas registered in `lib/data/datasources/isar_schemas.dart`. Additive — existing installs pick them up on next launch without migration.

---

## 5. Domain layer

```
lib/domain/
├── entities/gana/
│   ├── gana_entity.dart           freezed mirror of GanaModel
│   └── gana_run_entity.dart       freezed mirror of GanaRunModel
│
├── repositories/
│   ├── gana_repository.dart       upsert / list / enabled / byId / delete
│   │                              setEnabled / advanceCursor
│   └── gana_run_repository.dart   logRun / getRunsFor / getOutputEventIdsFor
│                                  pruneOldRuns
│
└── usecases/gana_usecases.dart    11 @lazySingleton use cases grouped:
                                     UpsertGanaUseCase
                                     GetGanasUseCase
                                     GetEnabledGanasUseCase
                                     GetGanaByIdUseCase
                                     DeleteGanaUseCase
                                     SetGanaEnabledUseCase
                                     AdvanceGanaCursorUseCase
                                     LogGanaRunUseCase
                                     GetGanaRunsUseCase
                                     GetGanaOutputEventIdsUseCase
                                     PruneGanaRunsUseCase
```

Two `@Injectable(as: ...)` repository impls in `lib/data/repositories/`:
`gana_repository_impl.dart` and `gana_run_repository_impl.dart`. All writes inside `isar.writeTxn`.

---

## 6. Single-run lifecycle

```
                ┌──────────────────────────────────────────┐
                │ Reactive watcher OR interval timer tick  │
                └──────────────────────────────────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │ Single-flight mutex held? │── yes ──► return (skip)
                    └───────────────────────────┘
                                  │ no
                                  ▼
                    ┌─────────────────────────────────────┐
                    │ Re-fetch GanaEntity from Isar       │
                    │ (config may have changed mid-debounce)│
                    └─────────────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────────────┐
                    │ Load self-output ids                │
                    │ Run GanaInputFilter (per-type)      │
                    └─────────────────────────────────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │ inputType != null AND inputs.isEmpty
                  ▼
        ┌───────────────────────────┐
        │ return (no cursor advance)│  next trigger re-tries
        └───────────────────────────┘
                  │ otherwise
                  ▼
                    ┌─────────────────────────────────────┐
                    │ Reply ancestry (up to 2 hops)       │
                    │ ManasContextLoader.merge            │
                    │ GanaPromptBuilder.build             │
                    └─────────────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────────────┐
                    │ SendPort ─► main isolate inference  │
                    │ Server gates:                        │
                    │  - hasActiveModel                    │
                    │  - desiredModelId == active          │
                    │ Else: skip codes via reply           │
                    └─────────────────────────────────────┘
                                  │
                ┌─────────────────┼─────────────────────────┐
                ▼                 ▼                         ▼
   skippedNoActiveModel  skippedCancelled  ok              failed
   skippedModelMismatch  (runner returned                  log run.failed
   noopReturned           null mid-stream)                 (no cursor advance)
        │                          │                       │
        ▼                          ▼                       │
   log run.skipped     log run.skipped(modelSwapped)      │
   (no cursor adv.)    (no cursor adv.)                   │
                                                          │
        ┌─────────────────────────────────────────────────┘
        │ ok
        ▼
    ┌─────────────────────────────────────┐
    │ Write GanaPendingOutputModel        │
    │ Log GanaRunModel.succeeded          │
    │ Advance cursor (eventId, time)      │
    └─────────────────────────────────────┘
        │
        ▼
    ┌─────────────────────────────────────┐
    │ Main-isolate GanaOutputDispatcher   │ ◄─ separate flow
    │   watches pending table             │   (runs continuously,
    │   ─► publish use case                │    not waited on by engine)
    │   ─► stamps outputEventId           │
    │   ─► deletes pending row            │
    └─────────────────────────────────────┘
```

Cursor is **never** advanced on skip or fail. The same input is retried on the next trigger. Idempotency falls out for free because the input filter is timestamp-cursor based + self-output guard.

---

## 7. Inference bridge — does it block the UI?

**No.** Here's why, with the actual call chain:

```
Engine isolate                            Main isolate
─────────────                              ────────────
_runInference()
  reply = ReceivePort()           ────►  GanaInferenceServer._onMessage(req)
  send GanaInferenceRequest                │
  await reply.first  ◄──── waits ────┐    │  ─► AIModelRunner.generateOneShot(prompt)
                                     │    │      │
                                     │    │      └─► LocalInferenceQueue.runLow(...)
                                     │    │            ─► serial behind chat (runHigh)
                                     │    │            ─► flutter_gemma in MAIN ISOLATE
                                     │    │            ─► returns String? when done
                                     │    │
                                     └────┴── reply.send(GanaInferenceResponse)
```

Key invariants:

1. **The engine isolate is NOT the UI thread.** All scheduling, Isar queries, Manas packing, prompt building, cursor bookkeeping happen in the engine isolate — never on the main isolate's frame budget.

2. **`await reply.first` parks the engine, not the UI.** A `ReceivePort` listen is asynchronous — the engine isolate yields to its own event loop while waiting. The main isolate keeps painting frames.

3. **The actual inference cost IS on the main isolate**, because flutter_gemma's native session is loaded there. BUT:
   - `flutter_gemma` runs inference on a **native thread** (MediaPipe / LiteRT-LM internals); the main isolate is only the orchestrator.
   - The async stream (`generateChatResponseAsync()`) yields control back to Flutter between tokens, so each frame can still tick.
   - Chat (high-priority lane) **preempts** Gana inference (low-priority lane) via `LocalInferenceQueue` — if the user opens Shiv mid-Gana-run, the chat turn cuts the line and the Gana queues behind it.
   - On low-end devices a generation burst CAN visibly slow scrolling for a few seconds; this is the same cost the existing Shiv chat already pays. Ganas use the same plumbing — no new performance hazard.

4. **`generateOneShot` returns `null` on preempt or model swap.** The engine treats this as `cancelled` → logs `modelSwapped` → does NOT advance cursor → next trigger retries cleanly.

So: **the bridge does NOT block the UI on the engine side, and the inference cost on the main side is the same cost Shiv chat already pays.** If you want zero main-isolate cost, the path is to make inference work in a background isolate — which is what §8 is about.

---

## 8. Background execution

> "if my app is running in the bg like i press the home button then running and if remove from the bg then stop right what are you trying to say"

Three states:

| App state | Engine isolate | WorkManager | What runs |
|---|---|---|---|
| **Foreground** | Active | Cancelled | Reactive + interval triggers fire; inference happens; publishes happen |
| **Backgrounded** (home pressed, still in recents) | Suspended by OS | One-shot fired ~30 min after pause | Tick only bumps `lastRunAt` on due Ganas. No inference. Foreground catches up on next open |
| **Killed** (swiped from recents) | Dead | Still fires (OS-level scheduler) | Same as backgrounded — cursor-bump only, no inference in v1 |

```
                              App lifecycle
                              ─────────────
                                    │
   ┌──────────────────┐             │             ┌──────────────────────┐
   │ FOREGROUND       │             │             │ BACKGROUND / KILLED  │
   │                  │ ──paused──► │ ──killed──► │                      │
   │ Engine isolate:  │             │             │ Engine isolate:      │
   │   reactive       │             │             │   suspended/gone     │
   │   interval       │             │             │                      │
   │   inference      │             │             │ WorkManager fires    │
   │   publish        │             │             │   every ~30 min:     │
   │                  │             │             │   bump lastRunAt     │
   │                  │ ◄─resumed── │             │   (no inference v1)  │
   └──────────────────┘             │             └──────────────────────┘
                                    │
                                    │ when user reopens:
                                    │   foreground engine sees
                                    │   bumped Ganas as "due" and
                                    │   runs inference immediately.
```

### 8.1 Native plumbing

| Platform | What we added | Why |
|---|---|---|
| Android | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS` permissions | foreground service required for tasks beyond 10-min wall budget; wake lock keeps the CPU awake for the tick |
| iOS | `UIBackgroundModes: fetch + processing`; `BGTaskSchedulerPermittedIdentifiers: in.uniun.app.gana.tick` | BGTaskScheduler refuses to launch a task whose identifier wasn't pre-declared |
| pubspec | `workmanager: ^0.6.0` | cross-platform background scheduler |

### 8.2 The unanswered question — v2 background inference

flutter_gemma 1.0.0's docs are silent on whether `FlutterGemma.initialize()` + `openChat()` work in a background isolate. We don't ship background inference in v1 because shipping unverified inference behaviour means broken Ganas that the user can't debug.

The test that answers this lives at `test/integration/flutter_gemma_bg_isolate_test.dart`. Move to `integration_test/` and run on a real device with a model already installed. Three outcomes:

- **OK** → green light. ~30-line patch in `gana_workmanager.dart` swaps the cursor-bump for real inference. Background Ganas become independent of foreground.
- **SKIP** → preconditions not met (no model installed). Re-run.
- **FAIL** → halt; ship queue-then-foreground forever (or until flutter_gemma adds bg-isolate support upstream). Document the limitation here in §8.

---

## 9. Self-loop + safety guards

| Layer | Guard | What it prevents |
|---|---|---|
| Input filter | `authorPubkey != selfPubkey` | Self-loops (Gana reads its own publish) + Gana-to-Gana ping-pong (one user's Gana A publishes → their Gana B reads → publishes → A reads → …) |
| Input filter | `eventId ∉ this Gana's output history` | Belt+suspenders against the same |
| Run gate | `desiredModelId == active OR null` | Per-Gana model preference; mismatched runs skip cleanly |
| Run gate | `FlutterGemma.hasActiveModel()` | Skip cleanly with `noActiveModel` if model is uninstalled |
| Cursor | NOT advanced on skip/fail | Same input retried next trigger; never lose work |
| Scheduler | Single-flight FIFO mutex | One Gana run at a time globally — predictable inference load |
| Queue | `LocalInferenceQueue.runLow` | Chat (`runHigh`) preempts; user never waits behind a Gana |
| Dispatcher | Retry capped at 3 | Publish failures eventually mark the run failed and stop hammering relays |
| Form | `enabled = false` default | User must explicitly turn on after reviewing config — no surprise publishes |
| Form | Interval ≥ 5 min | Foreground; background clamps to ≥ 30 min |
| Cleanup | Per-Gana 10 / global 1000 | `GanaRun` log doesn't grow unbounded; pruned every 6h |

---

## 10. UI placement

The **Shiv drawer** hosts Ganas alongside the existing chat history.

```
Shiv tab
  └─ ShivChatPage  Scaffold(drawer: ShivHistoryDrawer)
       └─ ShivHistoryDrawer (280 wide — matches Vishnu / Brahma)
            ├─ Header
            ├─ GANAS section (collapsible)
            │    ├─ "+ New Gana" → pushNamed(shivGanaForm)
            │    └─ GanaTile (× N)
            │         ├─ name
            │         ├─ trigger summary ("Reactive · Every 30m")
            │         ├─ last-run badge ("Succeeded · 2 min ago")
            │         ├─ tap     → pushNamed(shivGanaDetail, ganaId)
            │         └─ long    → bottom sheet (Enable/Disable, Edit, Delete)
            └─ CONVERSATIONS section (existing, unchanged behaviour)
```

`GanaFormPage` (route `shivGanaForm`):

```
┌──────────────────────────────────┐
│ New Gana                  Save   │
├──────────────────────────────────┤
│ Name                              │
│ [_____________________]           │
│                                   │
│ Description                       │
│ [_____________________]           │
│                                   │
│ MANASES                           │
│ Pick one or more …                │
│ [Rust Expert ✓] [Life Lessons]…   │  multi-select chips
│                                   │
│ Task prompt                       │
│ [ multi-line ]                    │
│                                   │
│ INPUT                             │
│ ▾ Public channel                  │  dropdown of GanaInputType
│ ▾ #daily-thoughts                 │  type-aware ref picker
│                                   │
│ OUTPUT                            │
│ ▾ Public channel                  │
│ ▾ #daily-thoughts                 │
│                                   │
│ MODEL                             │
│ ▾ Use whichever model is active   │  +N installed models
│                                   │
│ TRIGGERS                          │
│ [⬤] React to new input             │
│ Run every  [ 30 ] minutes (min 5) │
│                                   │
│ [⬤] Enabled                        │
│                                   │
│ (edit mode only)                  │
│ Delete Gana                       │
└──────────────────────────────────┘
```

`GanaDetailPage` (route `shivGanaDetail/:ganaId`) shows the same config as a read-only summary plus a list of the last 10 runs from `GanaRunModel`.

---

## 11. Folder structure

```
lib/
├── core/enum/
│   ├── gana_input_type.dart           channel/privateChannel/dm/user/followedNote
│   ├── gana_output_type.dart          feed/channel/privateChannel/dm
│   └── gana_run_status.dart           running/succeeded/skipped/failed
│                                      + GanaSkipReason enum
│
├── data/
│   ├── datasources/isar_schemas.dart  GanaModelSchema, GanaRunModelSchema,
│   │                                  GanaPendingOutputModelSchema registered
│   ├── models/
│   │   ├── gana_model.dart            Isar collection + toDomain ext
│   │   ├── gana_run_model.dart        Isar collection
│   │   └── gana_pending_output_model.dart  engine→main publish queue
│   └── repositories/
│       ├── gana_repository_impl.dart       @Injectable
│       └── gana_run_repository_impl.dart   @Injectable
│
├── domain/
│   ├── entities/gana/
│   │   ├── gana_entity.dart           freezed
│   │   └── gana_run_entity.dart       freezed
│   ├── repositories/
│   │   ├── gana_repository.dart       interface
│   │   └── gana_run_repository.dart   interface
│   └── usecases/gana_usecases.dart    11 @lazySingleton use cases
│
├── features/shiv/gana/
│   ├── engine/                         BACKGROUND ISOLATE
│   │   ├── gana_bootstrap.dart         spawn + Workmanager init + lifecycle
│   │   ├── gana_isolate.dart           entry point; opens own Isar
│   │   ├── gana_init_message.dart      handshake payload (SendPort, dir, pubkey)
│   │   ├── gana_engine.dart            scheduler + reactive + interval + mutex
│   │   ├── gana_input_filter.dart      per-type Isar queries + self-guards
│   │   ├── gana_prompt_builder.dart    task + INPUT + KNOWLEDGE + NOOP
│   │   ├── manas_context_loader.dart   multi-Manas union + budget pack
│   │   └── gana_workmanager.dart       top-level dispatcher (bg ticks)
│   │
│   ├── inference/                      MAIN ISOLATE
│   │   ├── gana_inference_protocol.dart   request/response classes (sendable)
│   │   ├── gana_inference_server.dart     @lazySingleton; bridges to AIModelRunner
│   │   └── gana_output_dispatcher.dart    @lazySingleton; drains pending → publish
│   │
│   ├── list/bloc/
│   │   ├── gana_list_bloc.dart        backs ShivHistoryDrawer Ganas section
│   │   ├── gana_list_event.dart
│   │   └── gana_list_state.dart
│   ├── form/
│   │   ├── bloc/                       gana_form_bloc/event/state
│   │   └── pages/gana_form_page.dart   create + edit
│   └── detail/pages/gana_detail_page.dart
│
├── gateway/cleanup/cleanup_manager.dart  + _pruneGanaRuns() phase (every 6h)
│
├── core/router/
│   ├── app_routes.dart                 shivGanaForm, shivGanaDetail constants
│   └── app_router.dart                 routes registered
│
├── features/shiv/chat/widgets/
│   └── shiv_history_drawer.dart        Ganas section added above Conversations
│
└── l10n/app_en.arb                     ganaForm*, ganaDrawer*, ganaTile*,
                                        ganaRun* keys (zero hardcoded English)

ios/Runner/Info.plist
  + UIBackgroundModes: fetch, processing
  + BGTaskSchedulerPermittedIdentifiers: in.uniun.app.gana.tick

android/app/src/main/AndroidManifest.xml
  + FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, WAKE_LOCK,
    RECEIVE_BOOT_COMPLETED, POST_NOTIFICATIONS permissions

pubspec.yaml
  + workmanager: ^0.6.0
  + flutter_gemma: ^1.0.0
  + flutter_gemma_litertlm / _mediapipe / _embeddings

test/integration/
  └── flutter_gemma_bg_isolate_test.dart   Phase 6a verification
                                           (move to integration_test/ to run)
```

---

## 12. Open follow-ups

| Item | Trigger to ship |
|---|---|
| **Background inference** | `flutter_gemma_bg_isolate_test.dart` PASS on a real device |
| **Function-calling output** | When flutter_gemma's tool-schema API is wired through our prompt path; currently plain text + `<NOOP>` sentinel |
| **Scoped vector retrieval** | When typical Manas size > prompt budget; currently direct-pack is fine |
| **Real `outputEventId` for DM + private channel** | Transport services (`SendDmUseCase`, `MarmotTransportService`) need to return event ids; currently the dispatcher synthesizes markers |
| **User-private config sync across devices** | Out of scope; would need encrypted Nostr-based sync layer |
| **"Run now" button** | Deferred; once we see how trigger model behaves in the wild |
