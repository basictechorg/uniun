# Ganas — User-Owned AI Agents on Top of Manas

> **Status**: Design doc. Phase 1 (Manas) shipped. This is Phase 2.
> **Companion**: builds on `manas.md` (or the inline Manas plan).
> **Target API**: `flutter_gemma ^0.16.5` (already in `pubspec.yaml`).
> The 1.0.0 bump is a separate parallel PR — every API used below is
> identical between 0.16.5 and 1.0.0.

---

## Part 1 — Functional

### 1.1  What is a Gana?

A **Gana** is a user-defined AI worker. The user gives it three things:

1. A **Manas** — the curated knowledge base (saved notes + their reference
   graph) the Gana is allowed to reason over.
2. A **task prompt** — plain English instructions for what the Gana should do
   (e.g. "Reply to messages in this channel with a relevant Life Lesson note
   from my Manas — quote the line that matters and add one sentence of
   commentary").
3. A **trigger + I/O wiring** — when does it run, what does it read, where
   does its output go.

Once enabled, the Gana runs by itself in a background isolate (no UI
attention required). Each run:

- gathers new input from the configured surface (a channel, a DM, a followed
  note, or "standalone — no input"),
- pulls relevant context from the configured Manas (Phase-1 saved-only
  membership; Phase-2 may extend to own/draft if the Manas owner adds them),
- composes a prompt with the user's task instructions,
- runs inference on the on-device model **sharing a single loaded copy of
  the model with the Shiv chat session** via `model.openChat()` (no second
  model load — see §2.4),
- publishes the result as a real Nostr event to the configured destination
  (feed, public channel, private channel, DM).

Ganas are **purely local config** — they are never broadcast as Nostr
events. Two devices owned by the same user will have independent Gana sets
until/unless we add a user-private config sync layer (out of scope here).

### 1.2  Lifecycle: triggers

Each Gana has **one or both** of these triggers (configurable
independently — a Gana can be reactive-only, interval-only, or both):

| Trigger | Fires when | Use case |
|---|---|---|
| **Reactive (event-driven)** | A new note arrives in the configured input surface that's newer than the Gana's cursor and not authored by the user themself. Debounced ~3s to coalesce bursts. | "Auto-reply in `#life-lessons` when someone posts" |
| **Interval (cron-like)** | A `Timer.periodic` ticks every N minutes (user-configurable; minimum 5). If `lastRunAt` was within `intervalMinutes`, the tick is a no-op. Anchored on `lastRunAt` so app restarts don't double-fire. | "Every morning at the daily check-in interval, publish a reflection to my journal channel" |
| **Both** | Either trigger may fire; both share the same cursor so they coalesce — a reactive run advances the cursor and the next interval tick sees no new input → skip. | Most realistic — react fast, but also do a periodic catch-up. |

There is no UI-driven "Run now" button in v1 (we may add it in v1.1 once we
see how the trigger model behaves in the wild).

### 1.3  Input scoping — what the Gana reads

A Gana's input is one of:

| Input type | Effective filter | Stored ref |
|---|---|---|
| **Channel** (public, NIP-28) | Kind-42 messages in that channel | `channelId` (hex) |
| **Private channel** (NIP-29) | Kind-9023 messages in that group | `groupId` |
| **DM conversation** | Kind-14/15 messages with that peer | `DmConversationModel.id` (stringified) |
| **User** | Kind-1 notes by that pubkey | `pubkeyHex` |
| **Followed note** | Any Kind-1 that references the note via NIP-10 `e` | `eventId` |
| **Standalone** | (no input) — the Gana fires on the interval alone | — |

Only surfaces the user is **already subscribed to** can be picked. The
gateway only writes Isar rows for what we've REQ'd, so reading from a
random channel we haven't joined would never see anything anyway. The
picker enforces this by sourcing options from `channelModels`,
`privateChannelModels`, `dmConversationModels`, `followedNoteModels`.

### 1.4  Knowledge — Manas as the context source

Every Gana points at exactly one Manas (FK by `manasId`). When the Gana
runs, the engine loads the Manas's membership through
`GetNoteIdsForManasUseCase`, resolves each id across
`savedNoteModels → noteModels → draftModels`, and **direct-packs** the
text into the prompt under a token budget (see §2.6).

There is **no vector search in v1** for Gana. Manas are small and curated
by hand — the user already implicitly ranked them by adding the notes.
Packing the whole Manas (or as much as fits in the budget, newest first)
is cheaper, deterministic, and runs in the engine isolate without an
embedder. Scoped-vector retrieval (passing an `allowedNoteIds` filter
into `VectorRepository`) is deferred to v1.1 when Manas size becomes a
real constraint.

### 1.5  Output — where the Gana publishes

Each Gana has one **output destination**, chosen at create time:

| Destination | Published as |
|---|---|
| **Main feed** | Kind-1 note signed by the user |
| **Public channel** | Kind-42 channel message (NIP-28) tagged to the chosen channel |
| **Private channel** | Kind-9023 group message routed through Marmot/MLS |
| **DM** | NIP-17 gift-wrapped DM to a chosen peer |

The Gana **does not** write to multiple destinations in one run. If the
user wants the same content fan-out, they create two Ganas with the
same Manas + task prompt, different outputs.

Output goes through the **existing publish use cases** —
`PublishNoteUseCase` / `CreateChannelMessageUseCase` /
`SendPrivateChannelMessageUsecase` / `SendDmUseCase` — which already
shape the event, write to `EventQueueModel`, and let the gateway
isolate broadcast. **No new publish path.** Tag-order discipline is
inherited for free.

### 1.6  UI placement — Shiv drawer

Ganas live in **the Shiv drawer**, mirroring how Manas lives in the
Brahma drawer. The existing `ShivHistoryDrawer`
(`lib/features/shiv/chat/widgets/shiv_history_drawer.dart`) and the
already-wired `Scaffold.drawer:` slot on `ShivChatPage` are extended
with a **collapsible "Ganas" section** above the existing
"Conversations" list:

```
┌─ SHIV ──────────────────────────╳─┐
│ Your on-device intelligence       │
├───────────────────────────────────┤
│ ▾  GANAS                  [+ New] │   ← collapsible
│    ┌─────────────────────────┐   │
│    │ ⚡ Life Lessons Replier  │   │
│    │   Channel · reactive    │   │
│    │   Last run · 2 min ago  │   │
│    └─────────────────────────┘   │
│    ┌─────────────────────────┐   │
│    │ 🕒 Daily Reflection       │   │
│    │   Standalone · every 24h │   │
│    │   Last run · 6 h ago    │   │
│    └─────────────────────────┘   │
│                                   │
│ ▾  CONVERSATIONS                  │   ← existing
│    • Yesterday's chat about Go    │
│    • RAG debugging session         │
│    …                              │
└───────────────────────────────────┘
```

- The drawer opens by **edge-swipe** from the left (Flutter default) or by
  **tapping the Shiv bottom-nav icon while already on Shiv** (consistent
  with how Brahma and Vishnu work). Both sections collapse independently
  so a user with many Ganas and many conversations can still navigate.
- **Each Gana tile** shows: name, input source summary, trigger summary,
  last-run timestamp + status. Tapping opens the Gana detail/edit page.
  Long-press → bottom sheet with Enable/Disable toggle + Edit + Delete.
- **+ New** at the section header opens the Gana form in create mode.

### 1.7  Create / edit form

One page (`GanaFormPage`) backs both. Fields:

1. **Name** (required, ≤60 chars)
2. **Description** (optional, multi-line)
3. **Manas** — dropdown of `GetManasListUseCase` results.
4. **Input source** — radio (Channel | Private channel | DM | User | Followed note | Standalone) → constrained picker for the chosen type.
5. **Output destination** — radio (Main feed | Public channel | Private channel | DM) → picker for the surface.
6. **Task prompt** — multi-line text (the user's instructions to the AI).
7. **Triggers** — two switches:
   - **Reactive** (only enabled if Input ≠ Standalone)
   - **Interval** with a minutes input (≥5)
8. **Enabled** — master on/off switch (defaults to **off**; user explicitly turns it on after reviewing the config — prevents accidental publishing).
9. **Last run log** (edit mode only) — last 10 `GanaRun` rows: timestamp, status (`succeeded | skipped | failed`), input event ids, output event id, error message.

Saving an edit just upserts the `GanaModel`; the engine isolate's
`ganaModels.watchLazy()` reloads its scheduling automatically.

### 1.8  What a Gana run looks like (worked example)

User config:
- Name: "Life Lessons Replier"
- Manas: "Life Lessons" (47 saved notes about stoicism, focus, etc.)
- Input: Channel `#daily-thoughts` (a public channel they joined)
- Output: Channel `#daily-thoughts` (same channel)
- Trigger: Reactive
- Task prompt: "When someone posts a question or reflection here, pick the
  most relevant note from my Manas and reply with a 1-2 sentence
  paraphrase that adds value. Reference the Manas note's author if known."

Run trace:
1. Bob posts kind-42 in `#daily-thoughts`: *"How do you handle a week where
   nothing seems to land?"*
2. Gateway writes it to `noteModels`. Engine isolate's
   `noteModels.watchLazy()` fires; debounced 3s.
3. Engine runs the input filter for this Gana: `noteModels` where
   `channelId = #daily-thoughts AND created > cursor AND kind = 42 AND
   authorPubkey ≠ self AND eventId ∉ self-output-history`. Picks Bob's
   message.
4. Engine loads Manas "Life Lessons" → resolves 47 ids across
   saved/own/draft → packs 28 of them under the budget (newest first).
5. Engine assembles prompt: task → INPUT (Bob's message) → KNOWLEDGE
   (the 28 packed notes) → "publish_message(channel_id, body)".
6. Engine calls `model.openChat()` on the shared model, sends prompt.
   Generation is auto-serialized by flutter_gemma — if Shiv chat is mid-
   stream, this turn queues behind it.
7. If the model supports function calling (Gemma 4 / Qwen3 / DeepSeek /
   Phi-4), the response is a structured `publish_message` call with
   `body`. Otherwise plain text is treated as the body (see §2.7).
8. Engine enqueues a Kind-42 via `CreateChannelMessageUseCase` (same path
   Brahma uses to send a channel message). Output event id is recorded.
9. Cursor advances. `GanaRun` row appended with `status: succeeded`,
   `inputEventIds: [bob_msg_id]`, `outputEventId: gana_msg_id`.
10. Gateway broadcasts. Bob (and everyone else in the channel) sees the
    reply within seconds.

### 1.9  Guards — what makes this safe

| Risk | Mitigation |
|---|---|
| **Self-loop** — Gana replies to a channel and its own reply triggers another run | Input filter drops notes where `authorPubkey == self_pubkey`. Plus a "drop notes whose event id is in `GanaRun.outputEventId`" guard for the same reason in case of multi-account oddness. |
| **Gana-to-Gana ping-pong** — Gana A posts to channel X, Gana B reads channel X and replies, etc. | Same self-pubkey guard covers it — every Gana's output is authored by the user, so it's filtered out of every Gana's input. |
| **Spam during model swap / model not installed** | Engine checks `FlutterGemma.hasActiveModel()` before each run. Missing → run is logged as `skipped` (not `failed`) and cursor does NOT advance, so the input is retried on the next trigger after the user installs a model. |
| **Quality regressions** | Each Gana is **off by default**. The user explicitly enables. The `GanaRun` log gives them per-run visibility. |
| **Runaway interval misconfig** (user sets 1 minute) | Form clamps minimum to 5 minutes. |
| **Inference monopolisation** — Gana hogs the model so Shiv chat stalls | flutter_gemma 0.16.5 serializes generation across sessions automatically. We additionally route every inference call through `LocalInferenceQueue` (already exists for Shiv) which gives chat a higher priority lane. |
| **Re-publish on app kill during enqueue → cursor advance window** | At most one duplicate per relaunch; relay dedups by event id. Acceptable v1. |

### 1.10  Non-goals for v1

- No "Run now" button in the UI.
- No multi-output destinations per Gana.
- No fan-in (a Gana reading from multiple channels at once).
- No tool-calling beyond the single `publish_message` tool.
- No user-private config sync across devices.
- No background execution when the app is killed (engine is app-open
  only — see §2.4 for why and what would change).
- No vector-retrieval scoped to a Manas (direct-pack only).
- No editable Manas membership from the Gana form (use the Manas form).
- No Gana templates / sharing.

---

## Part 2 — Technical

### 2.1  Layer overview

```
Shiv Drawer (UI)               ─┐
   ↓ Bloc events                │
GanaListBloc / GanaEditBloc    ─┤  ← all UI access via use cases,
   ↓ use cases                   │     never direct Isar
GanaRepository / GanaRunRepo   ─┘     ← Either<Failure, T>
   ↕ Isar (shared between main + gana isolates — same DB path)
Gana Engine Isolate            ─┐
   ├ scheduler                  │
   ├ input filter               │  ← watches noteModels.watchLazy() +
   ├ Manas context loader       │     ganaModels.watchLazy() for reloads
   ├ prompt builder             │
   ├ inference (via send-port → │
   │  main-isolate active model)│
   ├ output → EventQueueModel  ─┘
   ↕
Gateway Isolate (existing)         ← pumps EventQueueModel, broadcasts
```

The Gana engine is structurally identical to the gateway — a long-lived
isolate that owns no UI, watches Isar, and writes rows that another
party publishes. The only **departure** from the gateway pattern is
inference, which has to bridge back to the main isolate because the
gemma model is loaded there (see §2.4).

### 2.2  Data layer

#### 2.2.1  `lib/data/models/gana_model.dart`

```dart
@Collection(ignore: {'copyWith'})
@Name('Gana')
class GanaModel {
  Id id = Isar.autoIncrement;
  @Index(unique: true) late String ganaId;     // UUID
  late String name;
  String? description;

  /// FK → ManasModel.manasId. Never a hard relation — resolver-style.
  @Index() late String manasId;

  /// User-authored instructions injected into every prompt.
  late String taskPrompt;

  /// Input source. Null = standalone (no input fetch).
  @Enumerated(EnumType.name) GanaInputType? inputType;
  String? inputRefId;

  /// Output destination — exactly one set.
  @Enumerated(EnumType.name) late GanaOutputType outputType;
  String? outputChannelId;        // public channels
  String? outputGroupId;          // private channels
  Id? outputDmConversationId;     // DMs
  // outputType == feed → all output_* are null

  bool triggerReactive = false;
  int? triggerIntervalMinutes;

  bool enabled = false;

  // Cursor — what the engine has already consumed.
  String? lastProcessedEventId;
  DateTime? lastProcessedCreated;
  DateTime? lastRunAt;

  late DateTime createdAt;
  late DateTime updatedAt;
}
```

#### 2.2.2  `lib/data/models/gana_run_model.dart`

```dart
@Collection(ignore: {'copyWith'})
@Name('GanaRun')
class GanaRunModel {
  Id id = Isar.autoIncrement;
  @Index(unique: true) late String runId;
  @Index() late String ganaId;
  @Index() late DateTime startedAt;
  @Enumerated(EnumType.name) late GanaRunStatus status;
  List<String> inputEventIds = const [];
  String? outputEventId;          // also used as the self-loop guard set
  String? error;
}
```

Best-effort log. Older rows are pruned by `CleanupManager` (keep last
N per Gana, hard cap ~1000 globally).

#### 2.2.3  Enums

```dart
// lib/core/enum/gana_input_type.dart
enum GanaInputType { channel, privateChannel, dm, user, followedNote }

// lib/core/enum/gana_output_type.dart
enum GanaOutputType { feed, channel, privateChannel, dm }

// lib/core/enum/gana_run_status.dart
enum GanaRunStatus { running, succeeded, skipped, failed }
```

#### 2.2.4  Schema registration

Add `GanaModelSchema, GanaRunModelSchema` to
`lib/data/datasources/isar_schemas.dart`. Additive — no migration on
existing installs. (Existing devices will pick up the schemas on next
launch; Isar opens additional collections without touching old data.)

> **Note**: gana.md (the older draft) proposed a `GanaInferenceJobModel`
> bridge table. **We don't need it.** flutter_gemma 0.16.5+ multiplexes
> sessions on a single loaded model via `openChat()`; we bridge to the
> main isolate's model handle with a send-port instead of an Isar table
> (see §2.4). Less surface area, no I/O on the hot path.

### 2.3  Domain layer

- `lib/domain/entities/gana/gana_entity.dart` — freezed mirror of `GanaModel` (plus derived `noteCount` etc. if useful).
- `lib/domain/entities/gana/gana_run_entity.dart` — freezed.
- `lib/domain/repositories/gana_repository.dart` — `upsertGana / getGanas / getEnabledGanas / getGanaById / deleteGana / advanceCursor / logRun`.
- `lib/domain/usecases/gana_usecases.dart` — `@lazySingleton` per call: `UpsertGanaUseCase, GetGanasUseCase, GetEnabledGanasUseCase, GetGanaByIdUseCase, DeleteGanaUseCase, GetGanaRunsUseCase, ToggleGanaEnabledUseCase`.

Mirror the Manas slice structurally. One file per concept, use cases
grouped in `gana_usecases.dart`.

### 2.4  Engine isolate — `lib/features/shiv/gana/engine/`

#### 2.4.1  Bootstrap

`gana_bootstrap.dart` mirrors `lib/gateway/gateway.dart`:

```dart
class GanaBootstrap {
  static bool _started = false;
  static Future<void> start({
    required String isarDirectory,
    required SendPort mainInferencePort,
    required String selfPubkeyHex,
  }) async {
    if (_started) return;
    _started = true;
    await Isolate.spawn(
      ganaEntryPoint,
      GanaInitMessage(isarDirectory, mainInferencePort, selfPubkeyHex),
    );
  }
}
```

Called from `_HomePageState.initState` right after `GatewayBootstrap.start()`. Idempotent.

Why an isolate, given inference is bridged back? Because **scheduling
should never share the UI thread.** Reactive debouncing, periodic
timers, Manas packing, prompt assembly, JSON shaping, and EventQueue
writes are pure-Dart work that would otherwise compete with widget
rebuilds. Keeping it isolated also gives us a clean future swap to a
true background isolate (WorkManager) where the engine is identical
and only the inference backend changes.

#### 2.4.2  Inference bridge

The main isolate hosts `GanaInferenceServer` (`@lazySingleton`,
started in `HomePage.initState`). It owns a `ReceivePort` and
processes requests serially:

```dart
class GanaInferenceServer {
  final ReceivePort _port;
  SendPort get sendPort => _port.sendPort;

  Future<void> _onRequest(_InferenceRequest req) async {
    if (!FlutterGemma.hasActiveModel()) {
      req.replyPort.send(_InferenceResponse.skipped('no active model'));
      return;
    }
    final model = await FlutterGemma.getActiveModel(...);
    final chat = await model.openChat();          // ← new session per Gana run
    try {
      // If function-calling supported, register the publish_message tool
      // and parse the result. Else fall back to plain text.
      final out = await chat.sendMessage(req.prompt, tools: req.tools);
      req.replyPort.send(_InferenceResponse.ok(out));
    } catch (e) {
      req.replyPort.send(_InferenceResponse.failed(e.toString()));
    } finally {
      await chat.close();                          // free session
    }
  }
}
```

The engine isolate sends a request with `(prompt, tools, replyPort)`
and awaits the response. **One model load, N concurrent sessions, all
fair via flutter_gemma's built-in serialization.**

This makes the older gana.md `GanaInferenceJobModel` table obsolete —
the bridge is a port, not a DB row.

#### 2.4.3  Engine main loop

```dart
void ganaEntryPoint(GanaInitMessage init) async {
  final isar = await Isar.open(allSchemas, directory: init.isarDirectory);
  final engine = GanaEngine(
    isar: isar,
    inferencePort: init.mainInferencePort,
    selfPubkeyHex: init.selfPubkeyHex,
  );
  await engine.start();
}
```

Inside `GanaEngine.start()`:

1. Load enabled Ganas (`GetEnabledGanasUseCase` equivalent — direct Isar query in the isolate).
2. For each, wire **reactive** and **interval** triggers per its config.
3. Subscribe to `ganaModels.watchLazy()` — on any create/edit/delete/toggle, full reload (debounced 500ms so a bulk edit doesn't restart 10x).
4. Subscribe to `noteModels.watchLazy()` — feed all reactive Ganas with debounced (~3s) trigger checks.

Single-flight FIFO: one Gana run at a time globally. The reactive
debouncer coalesces, the interval timer is no-op if a run is in
flight or `lastRunAt + intervalMinutes > now`.

#### 2.4.4  One run

```dart
Future<void> _runOnce(GanaEntity gana) async {
  final newInput = await _fetchNewInput(gana);
  if (gana.inputType != null && newInput.isEmpty) {
    return; // nothing to do, don't advance cursor
  }
  final ctx = await ManasContextLoader.load(gana.manasId, budget: TOKEN_BUDGET);
  final prompt = PromptBuilder.build(
    task: gana.taskPrompt,
    input: newInput,
    knowledge: ctx,
  );
  final result = await _bridgeInfer(prompt, tools: _publishTool(gana));
  switch (result) {
    case _Ok(:final body):
      final outId = await _publish(gana, body);
      await _advanceCursor(gana, lastInput: newInput.lastOrNull, outputEventId: outId);
      await _logRun(gana, status: succeeded, inputEventIds: [...], outputEventId: outId);
    case _Skipped(:final reason):
      await _logRun(gana, status: skipped, error: reason); // cursor NOT advanced
    case _Failed(:final err):
      await _logRun(gana, status: failed, error: err);    // cursor NOT advanced
  }
}
```

#### 2.4.5  Input filter (per type)

```dart
Future<List<NoteModel>> _fetchNewInput(GanaEntity g) async {
  if (g.inputType == null) return const []; // standalone

  Query<NoteModel> q = isar.noteModels.filter()
      .createdGreaterThan(g.lastProcessedCreated ?? DateTime.fromMillisecondsSinceEpoch(0))
      .authorPubkeyNotEqualTo(selfPubkeyHex);

  q = switch (g.inputType!) {
    GanaInputType.channel       => q.channelIdEqualTo(g.inputRefId!).kindEqualTo(kChannelMessageKind),
    GanaInputType.privateChannel=> q.groupIdEqualTo(g.inputRefId!).kindEqualTo(kPrivateChannelKind),
    GanaInputType.dm            => q.conversationIdEqualTo(int.parse(g.inputRefId!)),
    GanaInputType.user          => q.authorPubkeyEqualTo(g.inputRefId!).kindEqualTo(kNoteKind),
    GanaInputType.followedNote  => q.eTagRefsElementEqualTo(g.inputRefId!),
  };

  var rows = await q.sortByCreated().limit(20).findAll();

  // Same-second tiebreak: drop the row we already processed.
  if (g.lastProcessedEventId != null && rows.isNotEmpty
      && rows.first.eventId == g.lastProcessedEventId) {
    rows = rows.skip(1).toList();
  }

  // Self-loop guard #2: drop any note that's in our own output history.
  final selfOutputs = await isar.ganaRunModels.filter()
      .ganaIdEqualTo(g.ganaId)
      .outputEventIdIsNotNull()
      .outputEventIdProperty()
      .findAll();
  final outSet = selfOutputs.toSet();
  rows = rows.where((r) => !outSet.contains(r.eventId)).toList();

  return rows;
}
```

### 2.5  Knowledge — `ManasContextLoader`

`lib/features/shiv/gana/engine/manas_context_loader.dart` (pure-Dart, isolate-friendly):

```dart
class ManasContextLoader {
  static Future<List<_PackedNote>> load(String manasId, {required int budget}) async {
    final ids = await isar.manasNoteLinkModels.filter()
        .manasIdEqualTo(manasId).noteIdProperty().findAll();

    final packed = <_PackedNote>[];
    var used = 0;

    // Resolve each id across saved → notes → drafts. Saved is the primary
    // source (Manas is saved-only in Phase 1); the other two are fallbacks
    // for forward compat with the Phase-2 multi-source Manas plan.
    for (final id in ids) {
      final note = await _resolve(id); // SavedNoteModel | NoteModel | DraftModel
      if (note == null) continue;
      final tokens = _estimateTokens(note.content);
      if (used + tokens > budget) break;
      packed.add(_PackedNote(...));
      used += tokens;
    }
    return packed;
  }
}
```

Token estimation = chars ÷ 4 (good enough for budgeting; the engine
adds a 15% safety margin to the budget before this loop).

**No embedder, no vector DB.** Phase 2A will revisit if Manas size
becomes a real constraint — when it does, the swap is local to this
loader.

### 2.6  Prompt assembly

```
<task_prompt>

INPUT MESSAGES (newest first):
- @<bob_pubkey_short> · 2 min ago: "How do you handle a week..."

KNOWLEDGE (your Manas "Life Lessons"):
- [note id abc] (2024-03-12): "..."
- [note id def] (2024-02-28): "..."
...

Respond by calling publish_message(channel_id, body).
If you have nothing meaningful to add, call publish_message with body="<NOOP>".
```

When function calling is unavailable, the prompt becomes:

```
... KNOWLEDGE ...

Reply with the message body only, no prefix. If you have nothing to say,
reply with exactly "<NOOP>".
```

`<NOOP>` (parsed case-insensitively, after trimming) → `_Skipped`, no
publish, cursor NOT advanced.

### 2.7  Function calling — `publish_message` tool

Where the active model supports it (Gemma 4 / Qwen3 / DeepSeek / Phi-4
per flutter_gemma docs), the engine registers:

```dart
final tool = ToolDef(
  name: 'publish_message',
  description: 'Publish a message to the configured output surface.',
  parameters: {
    'body': {'type': 'string', 'description': 'The message text to publish.'},
  },
);
```

The model is forced into tool-only output (where the API supports
`tool_choice: required` — Gemma 4 does, Qwen3 partial). On other
models, plain-text output is treated as the body verbatim.

`channel_id` etc. are **not** model-controlled — the Gana's output is
already fixed at config time. We register the tool with only `body` to
prevent the model from accidentally routing output somewhere else.

### 2.8  Output — publish

```dart
Future<String?> _publish(GanaEntity g, String body) async {
  return switch (g.outputType) {
    GanaOutputType.feed           => await getIt<PublishNoteUseCase>().call(body),
    GanaOutputType.channel        => await getIt<CreateChannelMessageUseCase>()
                                       .call((channelId: g.outputChannelId!, body: body)),
    GanaOutputType.privateChannel => await getIt<SendPrivateChannelMessageUsecase>()
                                       .call((groupId: g.outputGroupId!, body: body)),
    GanaOutputType.dm             => await getIt<SendDmUseCase>()
                                       .call((conversationId: g.outputDmConversationId!, body: body)),
  };
}
```

**Side note**: the engine isolate calls `getIt` only after its own
local DI container is configured at isolate spawn (the gateway already
does this — same pattern). The use cases there share the same Isar
instance opened in the isolate; the gateway picks up the
EventQueueModel row and ships it.

### 2.9  Self-loop & dedupe guards

(Detailed in §1.9 and embedded in §2.4.5.) Three layers:

1. `authorPubkey != selfPubkey` in the input filter.
2. `eventId ∉ outputEventIds(this Gana)` in the input filter.
3. flutter_gemma + the inference queue serializes inference so an
   in-flight Shiv chat turn blocks any Gana run that arrives —
   no overlap, no resource starvation.

### 2.10  UI plumbing — Shiv drawer extension

`lib/features/shiv/chat/widgets/shiv_history_drawer.dart` is renamed
conceptually to "the Shiv drawer" — same widget, now containing two
collapsible sections.

Top of the file:

```dart
return Drawer(
  width: 280, // match Vishnu / Brahma
  child: Column(children: [
    _ShivDrawerHeader(),
    Expanded(
      child: ListView(children: [
        _GanasSection(),         // NEW
        _ConversationsSection(), // existing history
      ]),
    ),
  ]),
);
```

Both sections are `ExpansionTile`-like (custom widgets matching the
project's visual language — see Brahma drawer `_DrawerSection` for the
reference look). Both default to open.

#### 2.10.1  `GanaListBloc` — `lib/features/shiv/gana/list/bloc/gana_list_bloc.dart`

Events: `LoadEvent`, `ToggleEnabledEvent(ganaId)`, `DeleteEvent(ganaId)`.
States: status + `List<GanaEntity>` (with last-run summary).

The bloc subscribes to `ganaModels.watchLazy()` and emits on changes
so the drawer auto-refreshes if a Gana edit happens elsewhere.

#### 2.10.2  `GanaEditBloc` — `lib/features/shiv/gana/form/bloc/gana_edit_bloc.dart`

Backs `GanaFormPage`. Standard create/edit pattern (mirror
`ManasFormBloc`). Events for each field, `SubmitEvent`, `DeleteEvent`.

#### 2.10.3  `GanaDetailPage`

Routed from a Gana tile tap. Hosts the edit form + a `GanaRunsView`
(scrollable list of the last 10 `GanaRun` rows for that Gana, with
expand-to-see-input-event-ids and copy-output-event-id affordances).

### 2.11  Routes (new in `app_routes.dart`)

```dart
shivGanaForm   = 'shivGanaForm';   // /shiv/gana/form
shivGanaDetail = 'shivGanaDetail'; // /shiv/gana/:ganaId
```

### 2.12  l10n keys (new in `app_en.arb`)

```
ganaDrawerSectionTitle, ganaDrawerEmptyStateBody, ganaDrawerNewButton,
ganaTileLastRun{when}, ganaTileTriggerReactive, ganaTileTriggerInterval{n},
ganaFormCreateTitle, ganaFormEditTitle, ganaFormSaveAction, ganaFormDeleteAction,
ganaFormNameLabel, ganaFormNameHint,
ganaFormDescriptionLabel, ganaFormDescriptionHint,
ganaFormManasLabel, ganaFormManasHint,
ganaFormInputTypeLabel, ganaFormInputTypeOption_{channel|privateChannel|dm|user|followedNote|standalone},
ganaFormInputRefLabel, ganaFormInputRefHint_{...},
ganaFormOutputTypeLabel, ganaFormOutputTypeOption_{feed|channel|privateChannel|dm},
ganaFormOutputRefLabel,
ganaFormTaskPromptLabel, ganaFormTaskPromptHint,
ganaFormTriggerReactiveLabel, ganaFormTriggerIntervalLabel, ganaFormTriggerIntervalHint,
ganaFormEnabledLabel, ganaFormEnabledHelp,
ganaFormRunsSectionTitle,
ganaFormDeleteConfirmTitle, ganaFormDeleteConfirmBody, ganaFormDeleteConfirmConfirm, ganaFormDeleteConfirmCancel,
ganaRunStatus_{running|succeeded|skipped|failed},
ganaRunNoOutput, ganaRunInputCount{n},
ganaErrorNoActiveModel, ganaErrorNoManas
```

(Then `flutter gen-l10n`.)

### 2.13  Build & verify

```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze lib
```

Manual e2e (covers everything new):

1. Install a model, create a Manas with ≥3 saved notes.
2. Create a Gana in the Shiv drawer: name, pick the Manas, input
   = a channel you're in, output = same channel, trigger reactive,
   write a task prompt, save, then flip Enabled on.
3. Post a message in the channel from another device (or another
   identity). Confirm the Gana publishes a reply within ~10s.
4. Confirm the Gana **does not** reply to its own reply (self-loop guard).
5. Disable the Gana. Post again. Confirm no reply.
6. Re-enable. Edit the task prompt. Confirm `ganaModels.watchLazy()`
   triggers a reload (engine logs show the schedule rebuilt).
7. Create a second Gana with interval-only standalone trigger,
   interval = 5 min, output = main feed. Confirm a Kind-1 appears
   within the interval window.
8. Kill the app while a Gana is mid-run. Relaunch. Confirm cursor
   bookkeeping kept things sane (at most one duplicate; relay dedups).
9. Uninstall the model. Trigger the Gana. Confirm it logs `skipped`
   with `no active model` and the cursor did NOT advance.
10. Long-press a Gana tile → Delete → confirm tile disappears and
    no further runs occur.

### 2.14  Edge cases / known limitations

- **App-open only** — Gana engine stops with the app. WorkManager
  backgrounding requires flutter_gemma to be verified in a true
  background isolate (RootIsolateToken-style). Not in v1. Architecture
  is ready for the swap — replace `GanaInferenceServer` with a
  background-isolate-local backend, no engine-code change.
- **Private channel input** — kind-9023 messages decrypted by
  Marmot/MLS must end up in `noteModels` with plaintext `content`.
  Verify in `kind9021_25_handler.dart` / `marmot_mls_service.dart`
  before enabling this input type in the picker. If ciphertext at
  rest, defer this one input type for v1.
- **Function calling parity** — Gemma 4 supports `tool_choice:required`
  cleanly; Qwen3 partial; Gemma 3 1B / 270M none. The engine falls back
  to plain-text + `<NOOP>` parsing on the lower tier. Document this in
  the model picker.
- **Manas growth past the budget** — direct-pack truncates at the budget.
  v1.1: optionally swap to scoped-vector retrieval (carry the
  `allowedNoteIds` through `VectorRepository.search`) once Manas
  routinely exceeds the budget.
- **Subscribed-surface enforcement** — pickers source from the local
  Isar collections of joined/known surfaces. We do not auto-join on
  the user's behalf. If the user joins a channel after creating a
  Gana for it, no migration needed — the channel was just empty
  locally before.
- **Two devices, same identity** — both engines run independently. The
  one with a model installed will publish; relay dedups. No
  coordination layer in v1.

---

## Open questions (to resolve before implementation)

1. **Gana priority lane in `LocalInferenceQueue`** — does Shiv chat
   strictly preempt, or just first-in-line? Current draft: first-in-line
   (chat will almost always win the race anyway).
2. **`GanaRun` retention** — keep last 10 per Gana, or per-time? Draft: per-count.
3. **Model-changed event** — should an in-flight Gana run be cancelled
   when the user swaps models, or allowed to finish on the old session?
   Draft: allow to finish (it's atomic — one prompt, one output).
4. **Function-calling JSON schema strictness** — accept loose JSON
   (`{ body: "..." }` without proper tool call) as a fallback path
   before falling all the way back to plain text? Draft: yes, two-tier
   parser.
