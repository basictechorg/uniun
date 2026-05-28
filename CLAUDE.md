# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# UNIUN — AI Context & Rules

This file is the single source of truth for any AI assistant working on this codebase. Read it completely before touching any file.

---

## What Is UNIUN?

UNIUN is a **decentralized, offline-first social and knowledge network** built entirely on the Nostr protocol, implemented as a Flutter mobile application. Users create, share, and connect **Notes** — Nostr Kind 1 events — that form both a social feed and a personal knowledge graph. Data is stored locally in an Isar database on the device and synced to the Nostr relay via WebSocket, managed by the EmbeddedServer (a separately maintained sync engine).

The app combines four systems into one: a social feed (Vishnu), a note creation workspace (Brahma), an AI assistant that reasons over the user's saved notes using on-device LLM inference (Shiv), and a public/private messaging layer (Channels + DMs). On-device AI runs via `flutter_gemma ^0.13.1` (user-selected model: Qwen3 0.6B / DeepSeek R1 / Gemma 4 E2B / Gemma 4 E4B) with no cloud API calls. The knowledge graph is not a separate construction — it emerges naturally from the Nostr event graph: every `e` tag is a graph edge, every `t` tag is a topic node, every reply thread is a directed conversation subgraph.

**The relay (`uniun-backend/`)** is a Go service built on Khatru (github.com/fiatjaf/khatru). It stores events in BadgerDB (primary) with optional MySQL mirror. Media blobs (Blossom protocol) are stored on Azure Blob Storage. The Flutter app's EmbeddedServer connects to this relay via WebSocket.

---

## Core Philosophy (NEVER Violate These)

- **Feed Freedom**: Notes are permanent. There is NO delete, NO soft-delete, NO NIP-09 implementation, NO `deleted` field, NO `isDeleted` field anywhere in any model, entity, or repository. Once published to Nostr, a note exists. The app does not pretend otherwise. This is an intentional design decision, not an oversight.

- **Offline-First**: The app works fully without internet. Isar is the source of truth. The UI reads only from Isar, never directly from a relay. EmbeddedServer syncs with relays when connectivity is available and writes results back to Isar.

- **No Backend**: Zero custom servers. No REST API. No GraphQL. No Firebase. Only Nostr relays (WebSocket protocol, NIP-01) and Blossom media servers (content-addressed HTTP blob store for images).

- **One Event Type for Notes**: Everything the user creates is a Nostr Kind 1 event — a "Note". There are no separate Post, Comment, Thread, or Reply models. Note roles (feed post vs reply vs reference) are **derived** from the presence or absence of `rootEventId` and `replyToEventId` fields. Never add a new model type that maps to a Reddit-style concept.

---

## Architecture

```
Flutter UI (Presentation Layer — BLoC)
    ↓ calls use cases
Domain Layer (entities, repository interfaces, use cases)
    ↓ implemented by
Data Layer (Isar models, repository implementations)
    ↑ written to by
EmbeddedServer (Dart Isolate — RelayConnector + SyncEngine + EventQueue + CleanupManager)
    ↔ WebSocket
Nostr Relay Network
```

**Key components:**
- **Flutter + BLoC**: State management via `flutter_bloc`. Events flow into BLoC, new States flow out to UI via `BlocBuilder`/`BlocListener`.
- **Clean Architecture**: Three strict layers — Data, Domain, Presentation — with unidirectional dependency flow (Presentation → Domain ← Data).
- **EmbeddedServer**: Built and maintained by a separate team. Runs in a Dart isolate. Manages relay WebSocket connections, incoming event processing, outgoing event queue, and retention cleanup. Do not modify EmbeddedServer internals.
- **Isar**: On-device NoSQL database. Object-based (no SQL). Used exclusively in the Data layer.
- **flutter_gemma**: On-device LLM runner for Shiv (AI assistant). Uses Google Gemma 2B or 7B via MediaPipe LLM Inference API. GPU-accelerated on Android (GPU delegate) and iOS (Metal).

### Layer Rules

**Data layer** (`lib/data/`):
- Contains Isar collection models (`@Collection`) and repository implementations.
- Models are **mutable** — no `@freezed` on Isar models (Isar requires mutable fields).
- May import `package:isar_community/isar.dart`.
- Must NOT import Flutter widget packages.
- Repository implementations are annotated `@Injectable(as: InterfaceName)`.
- All writes to Isar must be wrapped in `isar.writeTxn(() async { ... })`.

**Domain layer** (`lib/domain/`):
- Contains freezed entities, abstract repository interfaces, use cases, and input parameter classes.
- Has **zero** imports from `isar_community`, `flutter`, or any presentation package.
- Entities use `@freezed abstract class` pattern (Freezed 3.x requirement — not `class`).
- Repository interfaces define the contract; implementations live in `lib/data/repositories/`.
- Use cases extend `UseCase<ReturnType, InputType>` or `NoParamsUseCase<ReturnType>` from `lib/core/usecases/usecase.dart`.
- Results are always wrapped in `Either<Failure, T>` from the `dartz` package.

**Presentation layer** (`lib/presentation/` or feature folders like `lib/search/`, `lib/community/`):
- Contains BLoC classes, pages, and widgets.
- NO direct Isar access. All data flows through use cases → repositories.
- BLoC receives Events, calls use cases, emits States.
- Use `bloc_concurrency` for event transformers (e.g. `droppable()`, `sequential()`).

### Key Technical Decisions (from FINDINGS.md)

**Finding 001 — Unread Tracking via lastReadEventId**:
Unread badges for Channels and DMs are NOT implemented by marking all messages read on channel open. Instead, `ChannelReadStateModel` and `DMReadStateModel` each store a `lastReadEventId`. As the user scrolls, the last visible event ID is reported to the BLoC which updates `lastReadEventId`. `unreadCount = messages with createdAt after lastReadEventId`. This gives scroll-position resume (like Telegram's "you are here" marker) and a "jump to first unread" feature for free. The SyncEngine updates these models when new messages arrive.

**Finding 002 — On-Device LLM via flutter_gemma**:
Shiv uses `flutter_gemma ^0.13.1` as the single LLM backend. No Strategy pattern — one backend, no unnecessary abstraction. API: `FlutterGemma.getActiveModel(maxTokens:)` → `model.createChat()` → `InferenceChat`. Each user turn: `chat.addQuery(Message.text(text:))` + `chat.generateChatResponseAsync()` streams `TextResponse` tokens. `InferenceChat` manages conversation history internally — never rebuild history in our own prompt. The system instruction is prepended to the first user turn directly (Qwen chat templates ignore the `systemInstruction` param in `createChat()`). Supported models: Qwen3 0.6B, DeepSeek R1, Gemma 4 E2B, Gemma 4 E4B — user-selectable from `AIModelSelectionPage`.

**Finding 003 — Feed + Chat Use Same Scroll Model**:
Both the Vishnu feed and Channel/DM chat use the same `lastReadEventId` + chronological pagination pattern. Feed is chronological-only for v1 (no ranking algorithm). Pagination uses Isar's `createdLessThan(before)` cursor pattern. No separate architecture is needed for feed vs chat scroll.

**Finding 004 — GraphRAG: UNIUN's Nostr Graph IS the Knowledge Graph**:
Standard vector RAG retrieves notes by semantic similarity but fails at multi-hop queries and global summarization. GraphRAG solves both by traversing the note reference graph. UNIUN already has this graph for free: every `e` tag is a note→note edge (stored in `eTagRefs`), every `t` tag is a note→topic edge (stored in `tTags`), every reply thread is a directed conversation graph. No LLM entity extraction needed — these are user-asserted edges. v1 approach: seed with vector similarity, then BFS-expand via the graph. See `docs/graphrag.md` for full implementation details.

---

## Nostr Event Model

> Everything is a `NostrEvent`. The `kind` field determines meaning. There are no separate "users", "channels", or "posts" at the protocol level.

```
NostrEvent {
  id:         String  — SHA256 of canonical serialization
  pubkey:     String  — author's secp256k1 public key (this IS the user identity)
  created_at: int     — Unix timestamp
  kind:       int     — determines meaning
  tags:       List    — [[tag_name, value, ...], ...]
  content:    String  — meaning depends on kind
  sig:        String  — Schnorr signature over id
}
```

### Kind Reference (UNIUN-relevant)

| Kind  | Name                | Description                                      |
|-------|---------------------|--------------------------------------------------|
| 0     | User Metadata       | Profile (name, avatar, nip05, about)             |
| 1     | Short Text Note     | Public note — the primary unit in UNIUN          |
| 6     | Repost              | Repost of a Kind 1                               |
| 7     | Reaction            | Like or emoji on any event                       |
| 13    | Seal                | Layer 2 of encrypted DM (wraps Kind 14)          |
| 14    | DM Chat Message     | Actual DM content (inner rumor, unsigned)        |
| 40    | Channel Creation    | Creates a public channel; event ID = channel ID  |
| 41    | Channel Metadata    | Update channel name/description/icon             |
| 42    | Channel Message     | Message sent inside a channel                    |
| 1059  | Gift Wrap           | Outer envelope for encrypted DMs                 |
| 10063 | User Server List    | User's preferred Blossom media servers           |
| 24242 | Blossom Auth        | Signed auth token for Blossom uploads            |

### Tags Reference

```
["e", event_id, relay_url, marker, pubkey]  → references another event (graph edge)
["p", pubkey, relay_url]                    → references a user
["t", hashtag]                              → topic tag (graph node)
["a", kind:pubkey:d-tag, relay_url]         → reference to replaceable event
["imeta", "url ...", "m ...", "x ..."]      → inline media metadata (NIP-92)
```

**NIP-10 e-tag markers** (threading):
- `"root"` — the top-level post of the thread → stored as `rootEventId`
- `"reply"` — the direct parent being replied to → stored as `replyToEventId`
- `"mention"` — cited for reference only → stored in `eTagRefs`

### Note Roles (Derived, NOT Stored as a Field)

Note roles are inferred at query time. Never add a `role`, `isReply`, `isRoot`, or `noteRole` field to any model or entity.

| Role           | Condition                                    | UI location         |
|----------------|----------------------------------------------|---------------------|
| Top-level note | `rootEventId == null`                        | Vishnu feed         |
| Reply          | `rootEventId != null`                        | Thread view         |
| Reference      | `type == NoteType.reference`                 | Knowledge graph link|

---

## NIP Implementation Stack

### Used in UNIUN

| NIP    | Purpose                                                  |
|--------|----------------------------------------------------------|
| NIP-01 | Base event format, relay WebSocket protocol              |
| NIP-05 | Human-readable identifiers (`user@domain.com`) in profiles |
| NIP-10 | Reply threading via e-tag markers (root/reply/mention)   |
| NIP-17 | Private DMs (Kind 14 rumor format)                       |
| NIP-28 | Public channels (Kind 40 create / Kind 41 meta / Kind 42 msg) |
| NIP-44 | Encryption for DM payloads (ChaCha20-Poly1305)           |

### Explicitly NOT Used

| NIP    | Why excluded                                                      |
|--------|-------------------------------------------------------------------|
| NIP-09 | Event deletion — **permanently excluded**. Feed freedom is a core principle. Never implement. |
| NIP-04 | Legacy DM encryption (AES-CBC) — superseded by NIP-44.            |
| NIP-11 | Relay capability info — handled automatically by Khatru on relay; Flutter client does not implement. |
| NIP-59 | Gift wrap — future scope only (full 3-layer DM wrapping not yet built). |
| NIP-65 | Relay list metadata (Kind 10002) — relays managed locally in `RelayModel` (Isar), not via Nostr events. |

---

## Data Layer

Key files — read these directly rather than relying on this doc:
- `lib/data/models/note_model.dart` — `NoteModel` Isar collection
- `lib/domain/entities/note/note_entity.dart` — `NoteEntity` freezed
- `lib/domain/repositories/note_repository.dart` — repository interface
- `lib/core/error/failures.dart` — `Failure` freezed union
- `lib/core/usecases/usecase.dart` — `UseCase<T,P>` and `NoParamsUseCase<T>` base classes

**Critical field notes (NoteModel):**
- `rootEventId` and `replyToEventId` are NIP-10 threading fields. Both null = top-level feed note.
- `eTagRefs` stores ALL e-tag event IDs including root/reply/mention. `rootEventId`/`replyToEventId` are extracted separately.
- `cachedReactionCount` is denormalized; updated by SyncEngine when Kind 7 reactions arrive.
- `NoteType` enum (`text|image|link|reference`) stored as `EnumType.name` in Isar.

**Generated files — never edit manually.** Regenerate with:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
Build order: `freezed` runs before `isar_generator` (enforced via `pubspec.yaml` `global_options`).

---

## Package Versions (Critical — Do Not Upgrade Without Checking)

| Package                        | Version     | Why This Exact Version                                         |
|--------------------------------|-------------|----------------------------------------------------------------|
| `isar_community`               | `3.3.2`     | NOT `isar` 3.x — the original isar package is incompatible with Dart 3.x. Use `isar_community` fork. |
| `isar_community_flutter_libs`  | `3.3.2`     | Must match `isar_community` exactly                            |
| `isar_community_generator`     | `3.3.2`     | Must match `isar_community` exactly (dev dependency)           |
| `freezed`                      | `^3.0.0`    | NOT 2.x — v3 requires `abstract class` pattern for `@freezed` entities |
| `freezed_annotation`           | `^3.0.0`    | Must match `freezed` major version                             |
| `build_runner`                 | `^2.13.0`   | Needs `build_runner_core` 9.x compatibility                    |
| `injectable`                   | `^2.3.2`    | DI annotation framework                                        |
| `injectable_generator`         | `^2.4.1`    | DI code generator (dev dependency)                             |
| `dartz`                        | `^0.10.1`   | Functional Either/Option types                                 |
| `flutter_bloc`                 | `^8.1.3`    | BLoC state management                                          |
| `bloc_concurrency`             | `^0.2.4`    | Event transformers (droppable, sequential, restartable)        |
| Dart SDK                       | `>=3.2.4 <4.0.0` | Minimum Dart 3.2.4                                        |

**Isar import**: Always use `package:isar_community/isar.dart`. Never `package:isar/isar.dart`.

---

## Modules / Features

### Vishnu — Feed

The main chronological feed of Kind 1 notes.

- Displays top-level notes (`rootEventId == null`) newest-first.
- Pagination via `createdLessThan(before)` cursor on `NoteModel.created`.
- Unread tracking: `FeedReadStateModel` (Isar `@collection`, single row) stores `lastReadEventId` and `lastReadTimestamp`. As the user scrolls, the BLoC receives the last visible event ID via `UpdateFeedReadPositionEvent` and persists it.
- On next app launch, feed resumes from `lastReadEventId` position (Telegram-style "you are here" marker).
- No ranking algorithm in v1. Pure chronological.

**BLoC**: `VishnuFeedBloc`
- `LoadFeedEvent` → calls `GetFeedUseCase` → emits feed state
- `LoadMoreFeedEvent` → pagination with `before` cursor
- `RefreshFeedEvent` → reload from top
- `SaveNoteEvent` → calls `SaveNoteUseCase`
- `UpdateFeedReadPositionEvent` → updates `FeedReadStateModel`

### Brahma — Create Note

Note composition and publishing.

- Supports all `NoteType` values: `text`, `image`, `link`, `reference`.
- Image upload via Blossom protocol (Kind 24242 auth token, PUT to user's Blossom server, `imeta` tag in event).
- Reference picker allows selecting existing notes to create graph edges (`e` tags with `mention` marker).
- Graph preview shown before publishing (using `BuildNoteGraphUseCase`).
- Signs note with user's private key. Broadcasts via EmbeddedServer's EventQueue.
- Draft support via `DraftNoteRepository` (local only, not published to relay).

**BLoC**: `BrahmaCreateBloc`
- `UpdateContentEvent`, `AddReferenceEvent`, `RemoveReferenceEvent`
- `AttachImageEvent` → Blossom upload flow
- `TagUserEvent` → adds `p` tag
- `PreviewReferenceGraphEvent` → shows graph before submit
- `SubmitNoteEvent` → sign + enqueue for relay publishing

### Shiv — AI Assistant

On-device AI assistant using GraphRAG over the user's saved notes. Fully implemented.

**Model selection:**
- `AIModelSelectionPage` + `SelectAIModelCubit` — user picks from supported models (Qwen3 0.6B, DeepSeek R1, Gemma 4 E2B, Gemma 4 E4B).
- Selection stored in `AppSettingsModel` (Isar singleton). `AIModelRunner.hasActiveModel()` checks `FlutterGemma.hasActiveModel()`.
- `ShivPage` redirects to `AIModelSelectionPage` if no model is active.

**RAG pipeline (two-phase per InferenceChat design):**

Phase 1 — session open (once per conversation):
1. `RagPipeline.init()` — loads `EmbeddingService` (all-MiniLM-L6-v2 via tflite_flutter, ~80MB TFLite model).
2. `RagPipeline.buildSystemInstruction()` — loads active user profile + own notes → `PromptBuilder` emits Shiv persona + user name/bio/interests as a static system instruction string.
3. `AIModelRunner.initChat(systemInstruction:)` — opens an `InferenceChat` session via `flutter_gemma ^0.13.1`. The system instruction is prepended to the first user turn because Qwen templates ignore the systemInstruction parameter from `createChat()`.

Phase 2 — each user message:
1. `RagPipeline.buildMessage(userQuestion:)` returns a `RagMessage` containing the assembled per-turn string.
2. Internally: `EmbeddingService.embed(query)` → `VectorSearchService.search()` (cosine similarity, top-K) → 1-hop graph expansion via `GetGraphNeighboursUseCase` → memory lookup via `GetMemoriesByNoteIdsUseCase` → all results packaged into `EnrichedContext`.
3. `PromptBuilder.buildUserMessage(enrichedContext, PromptBudget)` — lays out the context within a per-model token budget. Priority order: user query → top seed notes → strong graph relations → remaining notes → memory summaries.
4. `AIModelRunner.sendAndStream(message)` → `chat.addQuery()` + `chat.generateChatResponseAsync()` → streams `TextResponse` tokens.
5. `InferenceChat` manages conversation history internally — we never duplicate it in our own prompt.

**Key classes in RAG:**
- `EnrichedContext` — bundle: `seedNotes` (vector hits) + `graphNodes` + `graphEdges` (1-hop expansion) + `memories` (wiki summaries via `MemoryNodeModel`).
- `PromptBudget` — per-model token allocation split across priority buckets (dynamic: smaller models = smaller budgets).
- `RagMessage` — output of `buildMessage()`: `userMessage` string + `contextCount` (how many items were injected).

**Thinking tag handling:**
- Models like DeepSeek R1 emit `<think>...</think>` blocks before the actual response.
- `ShivMessageBubble._parseThinking()` splits the raw text into `thinking` (collapsible) and `response` (visible) parts.
- The thinking block is capped at `maxThinkChars` if the model hits token limit mid-reasoning.
- **Bug to watch:** `<think>` tags only make sense inside Shiv. If they appear in channel thread or feed, the NoteCard does NOT strip them — that is a known issue caused by notes containing raw AI output text. No fix in place yet.

**Conversation persistence:**
- `ShivConversationModel` (Isar) — conversationId, title, activeLeafMessageId (branch pointer), createdAt, updatedAt.
- `ShivMessageModel` (Isar) — messageId, conversationId, parentId (linked-list for branching), role (user/assistant), content, createdAt.
- `parentId` chain enables the branch tree view. `activeLeafMessageId` tracks which leaf the user is reading.
- Auto-title: first user message → first 40 chars become the conversation title via `UpdateConversationTitleUseCase`.

**Memory nodes (new):**
- `MemoryNodeModel` (Isar) — wiki-style summaries associated with graph nodes, used as additional RAG context.
- Linked to notes via graph edges. Loaded by `GetMemoriesByNoteIdsUseCase` during RAG Phase 2.

**BLoC**: `ShivAIBloc` (events via `@freezed`)
- `loadConversations` → `RagPipeline.init()` + `GetConversationsUseCase`
- `createConversation` → `CreateConversationUseCase` → prepends to list immediately
- `openConversation(id)` → `GetMessagesUseCase` + `AIModelRunner.initChat()`
- `closeConversation` → return to conversation list view
- `sendMessage(text)` → RAG pipeline → streaming tokens
- `stopStreaming` → cancel native stream, persist partial response
- `switchBranch(leafMessageId)` → walk parentId chain from leaf to root, reload that path
- `createBranchFrom(parentMessageId)` → fork conversation from any node
- `selectGraphNode(messageId?)` → show action panel in branch tree view
- `tokenReceived`, `streamDone`, `streamError` — internal streaming events

**Use cases** (`lib/domain/usecases/shiv_usecases.dart`):
`GetConversationsUseCase`, `CreateConversationUseCase`, `DeleteConversationUseCase`, `GetMessagesUseCase`, `SaveMessageUseCase`, `UpdateMessageContentUseCase`, `UpdateConversationTitleUseCase`, `UpdateActiveLeafUseCase`

**UI structure** (`lib/features/shiv/`):
- `shiv/pages/shiv_page.dart` — model check → landing or active chat
- `shiv/chat/pages/shiv_chat_page.dart` — message list + streaming bubble
- `shiv/chat/tree/pages/shiv_branch_tree_page.dart` — visual conversation branch tree
- `shiv/chat/tree/widgets/branch_tree_graph.dart` — force-directed graph of message nodes
- `shiv/chat/tree/widgets/node_action_panel.dart` — action panel on node tap (branch/switch)
- `shiv/chat/widgets/shiv_history_drawer.dart` — side drawer (Scaffold.drawer), lists conversations
- `shiv/chat/widgets/shiv_conversation_tile.dart` — dismissible tile, swipe-to-delete
- `shiv/chat/widgets/shiv_input_composer.dart` — send bar with streaming lock
- `shiv/chat/widgets/shiv_message_bubble.dart` — user/assistant bubbles; parses `<think>` blocks
- `shiv/model_select/` — model picker UI (cubit + page + widgets)
- `shiv/rag/embedding/` — EmbeddingService (TFLite)
- `shiv/rag/pipeline/rag_pipeline.dart` — orchestrator
- `shiv/rag/prompt/prompt_builder.dart` — assembles LLM prompt
- `shiv/rag/prompt/prompt_budget.dart` — per-model token budgets
- `shiv/rag/retrieval/enriched_context.dart` — retrieval bundle type
- `shiv/rag/retrieval/vector_search_service.dart` — cosine similarity search
- `shiv/services/ai_model_runner.dart` — InferenceChat wrapper

### Channels — Public Chat (NIP-28)

- Kind 40 = channel creation. The `event.id` of the Kind 40 event **is** the channel ID forever. Never generate a separate channel ID.
- Kind 42 = channel message. Tagged with `["e", kind40_id, relay_url, "root"]`.
- Channel metadata updates via Kind 41 (creator only).
- Unread tracking via `ChannelReadStateModel` (same `lastReadEventId` pattern as feed).
- `DrawerBloc` manages channel list and DM list for the app drawer.
- Join public channel: `JoinChannelPage` + `JoinChannelQrScanPage` — user pastes a channel ID or scans a QR code. QR payload format: `{name, channel_id, relays}` (parsed by `JoinChannelQrParser`).
- Channel QR card: `UniunChannelQrCard.channel()` — shows channel header (name, about) + QR code using shared `UniunQrView`. Triggered from channel feed app bar.
- User profile QR card: `UniunQrCard.user()` — minimal dialog with `UniunQrView`. Triggered from drawer.
- QR scanner: `QrScannerPage` at `AppRoutes.scanQr` — scans any UNIUN QR and routes based on decoded payload kind.

### Private Channels (NIP-28 extension)

- Private channels use encrypted group messaging on top of Nostr Kind 42.
- Group ID is the channel identifier. Admin controls membership.
- Create: `CreatePrivateChannelPage` + `CreatePrivateChannelBloc`
- Join: `JoinPrivateChannelPage` + `JoinPrivateChannelBloc` — user pastes a group ID shared by admin.
- Chat: `PrivateChannelDetailPage` + `PrivateChannelDetailBloc` — message list, send, join request management for admin.
- Pending join requests shown in admin's app bar with badge count.
- `PrivateChannelModel`, `PrivateChannelMessageModel`, `PrivateChannelJoinRequestModel` — Isar collections.
- TODO: Add QR share button to private channel detail page (currently only "Copy Group ID" is in the popup menu). Needs `UniunChannelQrCard` wired to the group ID.

### DMs — Direct Messages (NIP-17)

- Kind 14 = the actual message content (called a "rumor" — it is UNSIGNED).
- Three-layer encryption: Kind 14 → NIP-44 encrypt → Kind 13 (seal) → NIP-44 encrypt with ephemeral key → Kind 1059 (gift wrap, published to relay).
- Only `["p", recipient_pubkey]` is visible on the relay.
- Subscription filter: `{"kinds": [1059], "#p": ["my_pubkey"]}`.
- Unread tracking via `DMReadStateModel` (same `lastReadEventId` pattern).

### Followed Notes

Subscribing to a note's reference graph — distinct from saved notes (which are for Shiv AI).

- `FollowedNoteModel` stores `eventId`, `contentPreview`, `followedAt`, `newReferenceCount`.
- EmbeddedServer opens `{"kinds":[1],"#e":["followedNoteId"]}` per followed note.
- `newReferenceCount` incremented by SyncEngine on each new match.
- **Cubit**: `FollowedNotesCubit` — `load()`, `followNote()`, `unfollowNote()`, `clearNewReferences()`
- **UX**: The drawer contains a collapsible "Followed Notes" section listing all followed notes with unread badges. Tapping a followed note directly opens `FollowedNoteDetailPage` (no separate list page). There is NO standalone `FollowedNotesPage` or `FollowedNoteFeedPage`.
- **Detail view**: `followed_notes/followed_note_detail/` — cubit (`FollowedNoteDetailCubit`) + page (`FollowedNoteDetailPage`) showing the original note and its incoming references.

---

## Gateway (Relay Sync Isolate)

The Gateway runs in a separate Dart isolate (`lib/gateway/`). It owns all relay WebSocket connections. The Flutter UI never touches the relay directly — Isar is the shared bus between isolates.

```
lib/gateway/
  ├── gateway.dart             — GatewayBootstrap.start() spawns the isolate
  ├── gateway_init_message.dart — carries isarDirectory path to the isolate
  ├── central_relay_manager.dart — orchestrates all relay services
  └── websocket_service.dart   — one WebSocket connection per relay URL
```

**How it works:**
- `GatewayBootstrap.start()` calls `Isolate.spawn(gatewayEntryPoint, GatewayInitMessage(isarDirectory))`.
- The isolate opens its own `Isar` instance at the same path — no `SendPort` needed. Isar is the interface.
- `CentralRelayManager` holds Isar `watchLazy()` subscriptions:
  - `EventQueueModel` watcher → new queue rows trigger immediate send on all write `WebSocketService`s.
  - `RelayModel` watcher → syncs `_services` map when relays are added/removed at runtime.
  - `FollowedNoteModel` watcher → refreshes `#e` REQ subscriptions.
  - `_dequeueTimer` (5 min) → purges queue entries older than 30 minutes.

**`WebSocketService` (one per relay):**
- Persistent connection, exponential backoff reconnect (max 60s).
- Outbound: cursor-based (`_lastSentQueueId`); one event in-flight, waits for `["OK"]` ACK.
- Channel events (Kind 40–44) routed to channel-specific relays via `ChannelModel.relays`; temporary services created for channel relays (5 min TTL).
- Inbound: stores received Kind 1 events to `NoteModel` (idempotent). Bumps `FollowedNoteModel.newReferenceCount` when e-tags match a followed note.

**Relay subscriptions the Gateway opens:**
```dart
// All Kind 1 notes (feed_notes subscription)
{"kinds": [1]}

// Followed note references — refreshed when FollowedNoteModel changes
{"kinds": [1], "#e": ["followedNoteId1", "followedNoteId2", ...]}

// Channel messages (per SubscriptionRecordEntity)
{"kinds": [41, 42], "#e": ["channelId"], "limit": 100}

// DMs (future — gift wraps addressed to this user)
{"kinds": [1059], "#p": ["myPubkey"]}
```

**Do not modify Gateway internals** — this code is owned by Parjaniya. The Flutter UI only reads/writes Isar.

**Isar retention policy (enforced by CleanupManager):**

| Note type                          | Retention              |
|------------------------------------|------------------------|
| Kind 1 (regular, not saved)        | 7 days (configurable)  |
| Kind 1 (saved = true)              | Forever                |
| Kind 1 (own note, own pubkey)      | Forever                |
| Kind 42 (channel message)          | 3 days (configurable)  |
| Kind 14 (DM content)               | Forever                |
| Kind 0 (profiles)                  | 30 days, refresh on view|
| AI conversations/messages          | Forever                |

On-demand fetch: if a note is referenced but not in Isar, `SyncEngine.fetchById(eventId)` queries the relay with `{"ids": [eventId]}`.

---

## BLoC Pattern

```
User action (tap, scroll, type)
    ↓
UI sends Event to BLoC: context.read<SomeBloc>().add(SomeEvent(...))
    ↓
BLoC handler calls use case: final result = await useCase.call(input)
    ↓
Use case calls repository: return await repository.doSomething(...)
    ↓
Repository reads/writes Isar, returns Either<Failure, Entity>
    ↓
BLoC folds the Either, emits new State
    ↓
UI rebuilds via BlocBuilder<SomeBloc, SomeState>
```

**Named BLoCs per module:**
- `VishnuFeedBloc` — feed
- `BrahmaCreateBloc` — note creation
- `ShivAIBloc` — AI assistant
- `GraphBloc` — knowledge graph view
- `DrawerBloc` — channels + DMs drawer
- `SavedNotesBloc` — saved notes management

**Event transformer usage (bloc_concurrency):**
- Use `droppable()` for search/query events (ignore new events while processing).
- Use `sequential()` for write operations (process in order).
- Use `restartable()` for user typing/input (cancel previous, start new).

---

## Dependency Injection

Uses `injectable` + `get_it`.

| Annotation                      | When to use                                        |
|---------------------------------|----------------------------------------------------|
| `@singleton`                    | `Isar` instance — one per app lifetime             |
| `@injectable`                   | Repository implementations, BLoC instances         |
| `@lazySingleton`                | Use cases — created on first access                |
| `@Injectable(as: Interface)`    | Repository impl registered as its interface        |

After adding any `@injectable`, `@singleton`, or `@lazySingleton` annotation, regenerate:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Blossom Media Upload

Blossom is a content-addressed HTTP blob store. File identity = SHA-256 hash. Same file on any Blossom server = same URL.

Upload flow:
1. User selects image → app computes SHA-256 locally.
2. `HEAD /<sha256>` on user's Blossom server — check if already uploaded.
3. If not found: sign Kind 24242 auth event (t=upload, x=sha256, expiration=+10min), `PUT /upload` with auth header + file bytes.
4. Receive blob descriptor: `{url, sha256, size, type}`.
5. Embed in note: `content` gets the URL, `tags` gets `["imeta", "url ...", "m image/jpeg", "x <sha256>", "dim WxH"]`.

User's Blossom servers declared in Kind 10063 event.

---

## Backend Responsibility Split

```
Flutter App (this repo)
    ↓ reads/writes
Isar DB (local, offline-first source of truth)
    ↑ written by
EmbeddedServer (Dart isolate — separate team)
    ↕ WebSocket (NIP-01)
uniun-backend/  ← Go relay (Khatru + BadgerDB + Blossom)
    ↕ optional mirror
MySQL

Flutter Brahma (image attach)
    → PUT /upload  (Blossom BUD-01)
uniun-backend Blossom handler
    → Azure Blob Storage
```

- **Flutter App (this repo)**: Create/sign notes, render UI from Isar, all user interactions
- **EmbeddedServer (Dart isolate — separate team)**: Saves relay events to Isar, manages WebSocket connections, EventQueue for offline sync. Do not modify.
- **uniun-backend/ (Go relay — this repo, `uniun-backend/` folder)**: Khatru-based Nostr relay. Accepts/stores events (BadgerDB primary, MySQL optional mirror). Handles Blossom media uploads via Azure Blob Storage. See `otodo.md` for build roadmap.

**Rule:** Never add direct HTTP calls from Flutter to the relay. Flutter only talks to Isar. The EmbeddedServer handles all relay communication.

The Flutter app **never talks to the relay directly**. It only reads/writes Isar. The Gateway handles all network sync.

---

## Datasource

There is no remote datasource in this app. The only datasource is Isar (local, on-device).

Each repository impl receives `Isar` via constructor injection. The Isar instance is opened once as a `@singleton` via `IsarModule`:

File: `lib/data/datasources/isar_module.dart`

```dart
@module
abstract class IsarModule {
  @singleton
  @preResolve
  Future<Isar> createIsar() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [NoteModelSchema, ProfileModelSchema, ...],  // add every new model schema here
      directory: dir.path,
    );
  }
}
```

**Rule**: Every new Isar `@Collection` model must have its generated schema added to `IsarModule.createIsar()`.

---

## User Storage Strategy

### Own User (the logged-in identity)

| What | Where | Retention |
|------|-------|-----------|
| Private key (nsec bech32) | `flutter_secure_storage` (Android Keystore / iOS Keychain) | Until logout |
| Public key (hex) + npub | Isar `UserKeyModel` | Until logout |
| Profile (Kind 0) | Isar `ProfileModel` with `lastSeenAt = DateTime(3000, 6, 1)` | Forever — sentinel date prevents eviction |

The private key is **never** written to Isar. `UserKeyModel` holds only the public identity.

On app launch, `SplashPage` calls `UserRepository.getActiveUser()`:
- `Right(user)` → skip onboarding, go to `HomePage`
- `Left(notFound)` → show `WelcomePage`

On reinstall, Isar is wiped but `flutter_secure_storage` may survive on Android (depends on backup settings). If Isar is empty but secure storage has the key, the user will be asked to log in again — the private key alone is insufficient without the Isar row.

### Other Users (feed / DM / channel participants)

| Category | Profile stored? | Retention |
|----------|----------------|-----------|
| Own user | ✅ Yes, `lastSeenAt = DateTime(3000,6,1)` | Forever (sentinel) |
| DM / Channel participants | ✅ Yes | Forever |
| Feed users (seen) | Temporarily | 30 days from `lastSeenAt` |
| Random unseen users | ❌ Not stored | — |

`ProfileModel.lastSeenAt` is updated each time the profile appears in the UI. The `CleanupManager` evicts profiles where `lastSeenAt < now - 30 days`. Own profile uses `DateTime(3000, 6, 1)` so it is never evicted — there is no `isOwn` boolean field.

### Followed Notes (NOT following people)

UNIUN does **not** implement a people-following / social graph in v1. There is no Kind 3 contact list, no follower count, no "following" list of users.

"Following a note" means subscribing to its **reference graph**: any new Kind 1 note that contains `["e", followedNoteId]` is captured and surfaced. This is implemented by:
- `FollowedNoteModel` (Isar) — stores `eventId`, `contentPreview`, `followedAt`, `newReferenceCount`
- `FollowedNoteRepository` — `followNote()`, `unfollowNote()`, `clearNewReferences()`, `isFollowed()`
- EmbeddedServer opens: `{"kinds":[1],"#e":["followedNoteId"]}` per followed note
- `newReferenceCount` is incremented by SyncEngine on each new match; cleared when user opens the feed

---

## What Is Already Built

Core identity, feed, threading, followed notes, settings, and onboarding are all implemented. Key modules:

| Area | Status |
|------|--------|
| Onboarding (welcome, key gen, import, profile setup) | ✅ Done |
| Home shell + floating nav (Vishnu / Brahma / Shiv tabs) | ✅ Done |
| Vishnu feed — BLoC, NoteCard, pagination, save/unsave | ✅ Done |
| Thread view — BFS load, nested replies, reply composer | ✅ Done |
| Followed notes — cubit, detail page, reference graph | ✅ Done |
| Settings — profile edit, identity, storage, style, alerts | ✅ Done |
| SavedNote — full note copy stored in Isar (not just ID) | ✅ Done |
| Brahma create note — BLoC, compose page, graph preview | ✅ Done |
| Shiv AI — model selection, RAG pipeline, conversation persistence, chat UI | ✅ Done |
| Gateway isolate (CentralRelayManager + WebSocketService) | ✅ Done |
| Public channels — create, feed, thread, join by QR (NIP-28) | ✅ Done |
| Private channels — create, join, chat, admin join-requests | ✅ Done |
| QR card + scanner (UniunQrCard / UniunChannelQrCard / QrScannerPage) | ✅ Done |
| Private channel QR share button | 🔲 Pending (add to PrivateChannelDetailPage) |
| DMs (NIP-17) | 🔲 Pending |

**NIP-09 (event deletion) is permanently excluded.** Notes are forever — this is a core product principle, not a gap. Never add a `deleted` field, Kind 5 event handling, or any soft-delete mechanism anywhere in the codebase.

---

## Localization (l10n)

All UI strings go through `AppLocalizations` — never hardcode text in widgets.

**Why:**
- **Translation** — want Hindi or Spanish? Add `app_hi.arb` with the same keys, translated. Flutter picks the right one based on phone language. Zero code change.
- **One place to edit** — want to change "Save & Continue" to "Done"? Change it in `app_en.arb`, updates everywhere instantly.
- **No typos across screens** — "Following" spelled wrong? Fix in one file, fixed on every screen.

**How to use:**
```dart
// In any widget build method:
final l10n = AppLocalizations.of(context)!;
Text(l10n.actionSave)
```

**Adding a new string:**
1. Add the key + English value to `lib/l10n/app_en.arb`
2. Run `flutter gen-l10n` (or `flutter pub get`)
3. Use `l10n.yourKey` in the widget

**Import:** `package:uniun/l10n/app_localizations.dart`

---

## Rules for AI Assistants

### DO

- Work one model/entity/feature at a time. Do not speculatively scaffold future features.
- **File grouping (SOLID SRP)**: Single Responsibility applies at the **class level**, not the file level. Group related classes of the same domain in one file — e.g., `note_usecases.dart` holds all Note use cases, `ai_model_usecases.dart` holds all AI model use cases. This is correct SOLID. Do NOT create one file per use case.
- Use `isar_community` package (import `package:isar_community/isar.dart`). Never `isar`.
- Use `abstract class` for all `@freezed` domain entities (Freezed 3.x requirement):
  ```dart
  @freezed
  abstract class SomeEntity with _$SomeEntity {
    const factory SomeEntity({...}) = _SomeEntity;
  }
  ```
- Keep Isar models mutable (`late` fields, no `@freezed`).
- Keep domain entities immutable (`@freezed abstract class`).
- Derive note role from `rootEventId`/`replyToEventId` — never add a separate `isReply`, `isRoot`, `role`, or `noteRole` field to any model or entity.
- Wrap all Isar writes in `isar.writeTxn(() async { ... })`.
- Return `Either<Failure, T>` from all repository methods and use cases.
- Use `Failure.errorFailure(e.toString())` in catch blocks.
- Check for existing records before inserting (idempotent saves).
- Annotate repository implementations with `@Injectable(as: RepositoryInterface)`.
- Run `build_runner` after any change to `@freezed`, `@collection`, or `@injectable` annotated classes.

### NEVER DO

- **Hardcode any UI string** — every piece of text shown to the user must come from `AppLocalizations` (l10n). Add the key to `app_en.arb` first, then use `l10n.yourKey` in the widget.
- Add `deleted`, `isDeleted`, `softDeleted`, or any deletion-related field to any model or entity.
- Implement or reference NIP-09 (Kind 5 deletion events).
- Import `package:isar_community/isar.dart` or any Isar type in the domain layer.
- Import Flutter widgets (`package:flutter/material.dart`, etc.) in the domain layer.
- Import Flutter widgets in the data layer.
- Create use cases for operations that do not have a concrete repository method backing them yet.
- Add `Post`, `Comment`, `Thread`, `Upvote`, or any Reddit-style model — everything is a `Note`.
- Add a `PostModel`, `CommentModel`, or any model that does not map to a Nostr event kind.
- Modify generated files (`*.g.dart`, `*.freezed.dart`) — they will be overwritten by `build_runner`.
- Use the old `isar` package — use `isar_community` only.
- Use Freezed 2.x `class` pattern — use Freezed 3.x `abstract class` pattern.
- Access Isar directly from BLoC or use cases — go through the repository interface.
- Hardcode Nostr event IDs or relay URLs.
- Touch EmbeddedServer internals — that is a separate team's concern.
- Push ranking/algorithm logic into the feed in v1 — chronological only.
- Add any form of cloud AI call — Shiv is entirely on-device.

---

## Common Code Patterns

### Adding a New Isar Model

```dart
// lib/data/models/some_model.dart
import 'package:isar_community/isar.dart';

part 'some_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('SomeName')  // explicit Isar collection name
class SomeModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  // ... other fields
}

extension SomeModelExtension on SomeModel {
  SomeEntity toDomain() => SomeEntity(/* map fields */);
}
```

### Adding a New Domain Entity

```dart
// lib/domain/entities/some/some_entity.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'some_entity.freezed.dart';

@freezed
abstract class SomeEntity with _$SomeEntity {
  const factory SomeEntity({
    required String id,
    // ...
  }) = _SomeEntity;
}
```

### Adding a New Repository Interface

```dart
// lib/domain/repositories/some_repository.dart
import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/some/some_entity.dart';

abstract class SomeRepository {
  Future<Either<Failure, SomeEntity>> getSomething(String id);
}
```

### Adding a New Repository Implementation

```dart
// lib/data/repositories/some_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/some_model.dart';
import 'package:uniun/domain/entities/some/some_entity.dart';
import 'package:uniun/domain/repositories/some_repository.dart';

@Injectable(as: SomeRepository)
class SomeRepositoryImpl extends SomeRepository {
  final Isar isar;
  SomeRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, SomeEntity>> getSomething(String id) async {
    try {
      // ... Isar query
      return Right(result.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
```

### Adding a New Use Case

```dart
// lib/domain/usecases/get_something_usecase.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/some/some_entity.dart';
import 'package:uniun/domain/repositories/some_repository.dart';

@lazySingleton
class GetSomethingUseCase extends UseCase<Either<Failure, SomeEntity>, String> {
  final SomeRepository repository;
  const GetSomethingUseCase(this.repository);

  @override
  Future<Either<Failure, SomeEntity>> call(String input, {bool cached = false}) {
    return repository.getSomething(input);
  }
}
```

---

## Folder Structure Reference

Every feature module MUST follow this exact folder pattern (derived from the established codebase convention):

```
feature_name/
├── bloc/        # BLoC classes (bloc, event, state) + .freezed.dart generated files
├── cubit/       # Cubit classes (cubit, state) — use when no events are needed
├── pages/       # Full-screen widgets (one file per screen/page)
├── widgets/     # Reusable UI components scoped to this feature
└── utils/       # Feature-specific helpers, extensions, formatters
```

**Rules:**
- Never put widgets directly in `pages/` and vice versa — keep them separated.
- `bloc/` and `cubit/` are separate folders. Use BLoC when you need events; use Cubit when state transitions are simple.
- Each file does ONE thing. A 500-line page file should be split into page + widgets.
- `utils/` only exists if there are actual helper functions. Don't create it empty.

```
lib/
├── main.dart
│
├── common/                        # Shared across the whole app
│   ├── locator.dart               # get_it DI setup
│   ├── locator.config.dart        # Generated injectable config
│   ├── snackbar.dart              # Global snackbar helpers
│   └── widgets/                   # Truly shared widgets (used by 2+ features)
│       ├── user_avatar.dart
│       └── floating_nav.dart
│
├── core/
│   ├── constants/                 # App-wide constants
│   ├── enum/
│   │   ├── note_type.dart         # NoteType: text | image | link | reference
│   │   ├── message_role.dart      # MessageRole: user | assistant
│   │   ├── outbound_status.dart
│   │   └── relay_status.dart
│   ├── error/
│   │   └── failures.dart          # Failure freezed union
│   ├── extensions/                # Dart extension methods
│   ├── router/
│   │   └── app_routes.dart        # Named route constants (see routes list below)
│   ├── scan/                      # QR + OCR scanner widgets (not feature-specific)
│   │   ├── uniun_qr_card.dart     # UniunQrCard.user() + UniunChannelQrCard.channel() + UniunQrView
│   │   ├── uniun_qr_payload.dart  # UniunQrPayload encode/decode
│   │   ├── qr_scanner_page.dart   # QrScannerPage (MobileScanner)
│   │   ├── uniun_card.dart        # Legacy OCR card (kept, not in use)
│   │   ├── uniun_payload.dart     # Legacy OCR payload (kept, not in use)
│   │   └── text_scanner_page.dart # Legacy OCR scanner (kept, AppRoutes.scanCard)
│   ├── theme/
│   │   └── app_theme.dart         # AppColors, AppTextStyles, ThemeData
│   └── usecases/
│       └── usecase.dart           # UseCase<T,P> and NoParamsUseCase<T> base classes
│
├── data/
│   ├── datasources/
│   │   ├── isar_module.dart       # Isar singleton — all schemas registered here
│   │   ├── isar_schemas.dart      # Schema list extracted for clarity
│   │   └── tostore_module.dart    # ToStore vector DB module
│   ├── models/                    # Isar @Collection models (mutable, no @freezed)
│   │   ├── notes/note_model.dart
│   │   ├── profile_model.dart
│   │   ├── user_key_model.dart
│   │   ├── channel_model.dart
│   │   ├── channel_message_model.dart
│   │   ├── private_channel_model.dart
│   │   ├── private_channel_message_model.dart
│   │   ├── private_channel_join_request_model.dart
│   │   ├── dm/dm_conversation_model.dart
│   │   ├── dm/dm_message_model.dart
│   │   ├── dm/encrypted_dm_model.dart
│   │   ├── shiv_conversation_model.dart
│   │   ├── shiv_message_model.dart
│   │   ├── memory_node_model.dart     # Wiki summaries for GraphRAG
│   │   ├── graph_node_model.dart
│   │   ├── graph_edge_model.dart
│   │   ├── saved_note_model.dart
│   │   ├── followed_note_model.dart
│   │   ├── event_queue_model.dart
│   │   ├── relay_model.dart
│   │   ├── app_settings_model.dart
│   │   ├── ai_model_selection_model.dart
│   │   └── missing_profile_pubkey_model.dart
│   └── repositories/              # Repository implementations (@Injectable)
│
├── domain/
│   ├── entities/                  # Freezed domain entities (immutable, @freezed abstract class)
│   ├── repositories/              # Abstract repository interfaces
│   ├── usecases/                  # Business logic (@lazySingleton, grouped by feature)
│   │   ├── shiv_usecases.dart
│   │   ├── ai_model_usecases.dart
│   │   ├── knowledge_usecases.dart  # graph + memory use cases
│   │   ├── user_usecases.dart
│   │   ├── profile_usecases.dart
│   │   └── ...
│   └── inputs/                    # Input parameter classes for use cases
│
├── l10n/                          # Auto-generated localization
│
├── gateway/                       # Relay sync isolate (do not modify — Parjaniya's code)
│   ├── gateway.dart
│   ├── gateway_init_message.dart
│   ├── central_relay_manager.dart
│   └── websocket_service.dart
│
│ ── ── ── FEATURE MODULES (all under lib/features/) ── ── ──
│
└── features/
    ├── onboarding/pages/          # Splash, Welcome, AboutYou, YourIdentityKeys, ImportIdentity
    ├── home/pages/                # HomePage (app shell)
    ├── vishnu/                    # Feed tab
    │   ├── bloc/                  # VishnuFeedBloc (event, state, freezed)
    │   ├── drawer/bloc/           # DrawerBloc
    │   ├── drawer/widgets/        # vishnu_drawer.dart
    │   ├── pages/                 # vishnu_feed_page.dart
    │   └── widgets/               # note_card.dart, feed_filter_chips.dart
    ├── brahma/                    # Create Note tab
    │   ├── bloc/                  # BrahmaCreateBloc
    │   ├── graph/bloc/            # GraphBloc
    │   ├── graph/pages/           # GraphPage, GraphComposePage
    │   └── pages/
    ├── shiv/                      # AI Assistant tab
    │   ├── chat/bloc/             # ShivAIBloc (event, state, freezed)
    │   ├── chat/pages/            # ShivChatPage
    │   ├── chat/tree/pages/       # ShivBranchTreePage (visual conv tree)
    │   ├── chat/tree/widgets/     # BranchTreeGraph, NodeActionPanel
    │   ├── chat/widgets/          # ShivHistoryDrawer, ConversationTile, InputComposer, MessageBubble
    │   ├── model_select/          # SelectAIModelCubit, AIModelSelectionPage, widgets
    │   ├── pages/                 # ShivPage
    │   ├── rag/embedding/         # EmbeddingService (TFLite)
    │   ├── rag/pipeline/          # RagPipeline
    │   ├── rag/prompt/            # PromptBuilder, PromptBudget
    │   ├── rag/retrieval/         # VectorSearchService, EnrichedContext
    │   └── services/              # AIModelRunner
    ├── thread/                    # Thread view (BFS replies)
    │   ├── bloc/                  # ThreadBloc
    │   ├── pages/                 # ThreadPage
    │   └── widgets/
    ├── channels/                  # Public channels (NIP-28)
    │   ├── create/                # CreateChannelBloc + CreateChannelPage
    │   ├── feed/                  # ChannelFeedBloc + ChannelFeedPage + ChannelMessageComposer
    │   ├── thread/                # ChannelThreadBloc + ChannelThreadPage
    │   └── join/                  # JoinChannelBloc + JoinChannelPage + JoinChannelQrScanPage
    │                              #   join_channel_qr_parser.dart — payload: {name, channel_id, relays}
    ├── private_channels/          # Private channels
    │   ├── create/                # CreatePrivateChannelBloc + page
    │   ├── join/                  # JoinPrivateChannelBloc + page
    │   └── detail/                # PrivateChannelDetailBloc + page
    ├── dm/                        # Direct messages (NIP-17, UI pending)
    │   ├── create/                # CreateDmBloc + CreateDmPage
    │   └── chat/                  # DmChatPage
    ├── followed_notes/cubit/      # FollowedNotesCubit
    ├── saved_notes/               # SavedNotesCubit + SavedNotesPage
    └── settings/                  # SettingsCubit, EditProfileCubit, StorageCubit + pages/widgets
```

**Named routes** (`lib/core/router/app_routes.dart`):
```dart
splash, welcome, importIdentity, yourIdentityKeys, aboutYou
home, settings, editProfile, privacyPolicy
thread, followedNoteDetail
aiModelSelection, graph, brahmaCreate
createChannel, joinChannel, channelDetail
createPrivateChannel, joinPrivateChannel, privateChannelDetail
savedNotes, createDm, chatDm
scanCard   ← legacy OCR scanner (kept)
scanQr     ← QR scanner (active)
```

---

## Frequently Made Mistakes

1. **Using `class` instead of `abstract class` with `@freezed`** — Freezed 3.x requires `abstract class`. This causes a compile error.

2. **Importing `package:isar/isar.dart`** — The project uses `isar_community`. The original `isar` package will not resolve.

3. **Adding a `deleted` field** — Do not do this. Ever. Not even temporarily. Feed Freedom.

4. **Skipping `build_runner`** — After any change to a `@freezed`, `@Collection`, or `@injectable` class, you MUST run `flutter pub run build_runner build --delete-conflicting-outputs`. The generated files will be out of sync otherwise.

5. **Creating Post/Comment models** — There are no posts or comments. There are only Notes (Kind 1 events). If it's user-created content, it's a Note.

6. **Accessing Isar from a use case or BLoC** — Use cases and BLoC must not import or use Isar directly. Go through the repository interface.

7. **Forgetting `writeTxn`** — All Isar mutations (put, delete) must be inside `isar.writeTxn(() async { ... })`. Reads do not need a transaction.

8. **NIP-10 field confusion** — `eTagRefs` holds ALL e-tag event IDs. `rootEventId` is specifically the e-tag with `"root"` marker. `replyToEventId` is specifically the e-tag with `"reply"` marker. They are not redundant — `eTagRefs` includes all of them plus `"mention"` tags.
