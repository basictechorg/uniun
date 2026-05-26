# UNIUN Codebase Guide
## BLoC Architecture & Layered Design — UNIUN-Specific

---

## Part 1: What is UNIUN?

**UNIUN** is a **decentralized, offline-first social and knowledge network** built on the Nostr protocol. Everything is a **Note** (Nostr Kind 1 event). There are no posts, comments, threads, or users as separate concepts — a user IS their public key, and a note is the only unit of content.

Four modules:
- **Vishnu** — chronological note feed
- **Brahma** — create/publish notes
- **Shiv** — on-device AI assistant (RAG over saved notes)
- **Channels + DMs** — public chat (NIP-28) and direct messages (NIP-17)

All data is stored locally in **Isar** and synced via the **EmbeddedServer** (a Dart isolate — not written by this team).

---

## Part 2: The 3-Layer Architecture

```
┌──────────────────────────────────────┐
│  PRESENTATION  (BLoC + UI widgets)   │
│  Pages, BLoCs, Cubits                │
└─────────────────┬────────────────────┘
                  │ calls use cases
                  ↓
┌──────────────────────────────────────┐
│  DOMAIN  (business rules)            │
│  Entities, Use Cases, Repo Interfaces│
└─────────────────┬────────────────────┘
                  │ implemented by
                  ↓
┌──────────────────────────────────────┐
│  DATA  (storage)                     │
│  Isar models, Repository impls       │
└──────────────────────────────────────┘
         ↑ written to by EmbeddedServer
```

**Rules that NEVER break:**
- Presentation never imports Isar directly — only calls use cases.
- Domain never imports Flutter or Isar — pure Dart.
- Data layer returns `Either<Failure, T>` — never throws raw exceptions to callers.

---

## Part 3: Each Layer in Detail

### DATA LAYER (`lib/data/`)

Isar `@Collection` models (mutable) + repository implementations.

```
NoteModel (Isar)       → NoteRepositoryImpl
SavedNoteModel (Isar)  → SavedNoteRepositoryImpl
ShivConversationModel  → ShivRepositoryImpl
ShivMessageModel       → ShivRepositoryImpl
EventQueueModel        → (read by EmbeddedServer's WebSocketService)
DmConversationModel    → (pending: DmRepositoryImpl)
DmMessageModel         → (pending: DmRepositoryImpl)
AppSettingsModel       → AIModelRepositoryImpl
AIModelSelectionModel  → AIModelRepositoryImpl
```

All writes: `isar.writeTxn(() async { ... })`.
All reads: direct Isar query — no transaction needed.
Duplicate saves are idempotent (check before insert).

### DOMAIN LAYER (`lib/domain/`)

Freezed entities + abstract repository interfaces + use cases.

```
NoteEntity             ← NoteModel.toDomain()
SavedNoteEntity        ← SavedNoteModel.toDomain()
ShivConversationEntity ← ShivConversationModel.toDomain()
ShivMessageEntity      ← ShivMessageModel.toDomain()
AIModelEntity          ← AIModelSelectionModel.toDomain()
ScoredNote             ← (vector search result, not an Isar model)
```

Use cases extend `UseCase<ReturnType, InputType>` or `NoParamsUseCase<ReturnType>`.
Results: always `Either<Failure, T>`.
Grouped by feature in one file (SRP = class level, not file level):
- `note_usecases.dart`, `shiv_usecases.dart`, `ai_model_usecases.dart`, `vector_usecases.dart`, `saved_note_usecases.dart`

### PRESENTATION LAYER (feature folders)

BLoCs and pages. NO Isar imports. All data via use cases.

Event transformers (bloc_concurrency):
- `droppable()` — queries (load, open)
- `sequential()` — writes (save, delete, send message)
- `restartable()` — user typing (search input)

---

## Part 4: BLoC Pattern — Concrete Example (Shiv AI)

User sends "What do my notes say about Nostr?":

```
ShivChatPage
  ↓ context.read<ShivAIBloc>().add(ShivAIEvent.sendMessage("What do my notes…"))

ShivAIBloc._onSendMessage:
  1. emit(state.copyWith(status: streaming, streamingContent: ''))
  2. SaveMessageUseCase(userMessage)         → Isar write
  3. RagPipeline.buildMessage(userQuestion)  → embed query → cosine search → prompt
  4. AIModelRunner.sendAndStream(prompt)     → InferenceChat stream
  5. each token → add(_TokenReceived(token)) → emit(state.copyWith(streamingContent: ...))
  6. _StreamDone → UpdateMessageContentUseCase(assistantMessage) → emit idle

ShivChatPage (BlocConsumer):
  - listenWhen: messages.length changed → scrollToBottom
  - builder: renders ListView of ShivMessageBubble
    - last bubble gets streamingContent while status == streaming
```

---

## Part 5: EventQueueModel — Outbound Relay Queue

`EventQueueModel` is the durable outbound queue for signed Nostr events.

```dart
@Collection() @Name('EventQueue')
class EventQueueModel {
  Id id = Isar.autoIncrement;    // ordered cursor — each WebSocketService
                                  // tracks its own _lastSentQueueId
  String eventId;                 // Nostr SHA256 event ID (unique)
  String authorPubkey, sig, content;
  int kind;
  List<String> eTagRefs, pTagRefs, tTags;
  String? rootEventId, replyToEventId;
  DateTime created;
  int sentCount;       // incremented by each relay on ["OK", id, true] ACK
  DateTime enqueuedAt; // dequeue gate: sentCount >= relayCount AND age > 30min
}
```

`toSerializedRelayMessage()` produces the NIP-01 wire format: `["EVENT", {...}]`.

`populateFromNoteModel()` / `populateFromNoteEntity()` build a queue row from a published note.

**Who reads it:** EmbeddedServer's `WebSocketService` (separate team — do not modify).
**Who writes it:** `PublishNoteUseCase` → `EventQueueRepositoryImpl` (via `isar.writeTxn()`).

---

## Part 6: DM Data Models

`DmConversationModel` and `DmMessageModel` are Isar collections for NIP-17 direct messages.

```
DmConversationModel — one row per 1:1 conversation (identified by the other party's pubkey)
DmMessageModel      — one row per Kind 14 message within a conversation
```

UI (Channels + DMs BLoC) is pending. Schema is in place and `.g.dart` files are generated.

---

## Part 7: Folder Structure

**IMPORTANT:** All feature modules moved to `lib/features/` (PR #36 — folder restructure). Do not use the old flat paths.

```
lib/
├── common/           # get_it locator, snackbar, floating_nav, shared widgets
├── core/
│   ├── enum/         # NoteType, MessageRole, OutboundStatus, RelayStatus
│   ├── error/        # Failure freezed union
│   ├── router/       # AppRoutes constants
│   ├── scan/         # QR + OCR scanner widgets (shared, not feature-specific)
│   │   ├── uniun_qr_card.dart     # UniunQrCard.user() + UniunChannelQrCard.channel() + shared UniunQrView
│   │   ├── uniun_qr_payload.dart  # encode/decode JSON QR payloads
│   │   ├── qr_scanner_page.dart   # live QR scanner (MobileScanner)
│   │   ├── text_scanner_page.dart # legacy OCR scanner (kept, not in use)
│   │   ├── uniun_card.dart        # legacy OCR card (kept)
│   │   └── uniun_payload.dart     # legacy OCR payload (kept)
│   ├── theme/        # AppColors, AppTheme
│   └── usecases/     # UseCase<T,P> base classes
├── data/
│   ├── datasources/
│   │   ├── isar_module.dart    # Isar singleton — ALL schemas registered here
│   │   ├── isar_schemas.dart   # schema list
│   │   └── tostore_module.dart # vector DB
│   ├── models/       # Isar @Collection models — includes MemoryNodeModel (GraphRAG)
│   └── repositories/ # Repository impls (@Injectable)
├── domain/
│   ├── entities/     # @freezed abstract class entities
│   ├── repositories/ # Abstract interfaces
│   └── usecases/     # Business logic (@lazySingleton, grouped by feature)
│                     # knowledge_usecases.dart — graph + memory use cases (new)
├── gateway/          # Relay sync isolate — do not modify (Parjaniya's code)
├── l10n/             # Generated — all UI strings via AppLocalizations
│
└── features/         # ← ALL feature modules live here
    ├── onboarding/
    ├── home/
    ├── vishnu/        # Feed + Drawer
    ├── brahma/        # Create Note + Graph
    ├── shiv/          # AI assistant (RAG pipeline, branch tree, model select)
    ├── thread/        # Thread view
    ├── channels/      # Public channels: create, feed, thread, join (+ QR join)
    ├── private_channels/  # Private channels: create, join, detail
    ├── dm/            # DMs (NIP-17) — UI pending
    ├── followed_notes/
    ├── saved_notes/
    └── settings/
```

---

## Part 8: Key Concepts

### Freezed entities (domain layer)
```dart
@freezed
abstract class ShivConversationEntity with _$ShivConversationEntity {
  const factory ShivConversationEntity({
    required String conversationId,
    required String title,
    String? activeLeafMessageId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ShivConversationEntity;
}
// copyWith() auto-generated — no manual mutation
```

### Either (success or failure)
```dart
final result = await getConversations.call();
result.fold(
  (failure) => emit(state.copyWith(status: error, errorMessage: failure.toString())),
  (list)    => emit(state.copyWith(conversations: list)),
);
```

### Injectable DI
```dart
@injectable          // for BLoCs and repos
@lazySingleton       // for use cases and services
@singleton           // for Isar instance only

// Usage:
getIt<ShivAIBloc>()  // auto-constructed with all dependencies
```

### Localization — all UI strings via l10n
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.shivName)  // never hardcode strings in widgets
```
Add keys to `lib/l10n/app_en.arb`, then run `flutter gen-l10n`.

---

## Part 9: What's Built vs Pending

| Module | Status |
|--------|--------|
| Onboarding (welcome, key gen, import) | ✅ Done |
| Home shell + nav | ✅ Done |
| Vishnu feed (BLoC, NoteCard, pagination, save/unsave) | ✅ Done |
| Thread view (BFS load, nested replies) | ✅ Done |
| Followed notes (cubit, detail page) | ✅ Done |
| Settings (profile edit, identity, storage, AI, style) | ✅ Done |
| Brahma create note (BLoC, compose, graph preview) | ✅ Done |
| Shiv AI — model select, RAG, GraphRAG, branch tree, streaming | ✅ Done |
| EventQueueModel + relay wire format | ✅ Done |
| Public channels — create, feed, thread, join (QR + manual) | ✅ Done |
| Private channels — create, join, detail, admin requests | ✅ Done |
| QR card system (UniunQrCard, UniunChannelQrCard, QrScannerPage) | ✅ Done |
| DM models (schema) | ✅ Done |
| Private channel QR share button | 🔲 Pending |
| DMs UI (NIP-17) | 🔲 Pending |
