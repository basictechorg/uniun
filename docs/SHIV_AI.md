# Shiv AI — Complete System Design

Shiv is UNIUN's on-device AI assistant. It reasons over the user's saved notes using vector RAG, runs entirely offline using `flutter_gemma`, and supports a branching conversation tree that looks like a normal chat by default.
resource : - https://pub.dev/packages/flutter_gemma , https://pub.dev/documentation/flutter_gemma/latest/ 
---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [RAG Pipeline](#rag-pipeline) — including baseline personalization (profile + own notes, works without saved notes)
3. [Model Selection & Download](#model-selection--download)
4. [Branching Chat System](#branching-chat-system)
5. [Data Models](#data-models)
6. [BLoC Structure](#bloc-structure)
7. [UI Flow](#ui-flow)
8. [Build Sequence](#build-sequence)

---

## Architecture Overview

```
User question
      ↓
ShivAIBloc (SendMessageEvent)
      ↓
EmbeddingService → query vector (all-MiniLM-L6-v2, on-device)
      ↓
VectorSearchService → cosine sim over SavedNoteModel.embedding in Isar → top-K notes
      ↓
PromptBuilder → system prompt + saved note context + branch conversation history
      ↓
AIModelRunner (flutter_gemma 0.13.1) → streams tokens
      ↓
ShivAIBloc emits streaming state updates
      ↓
Chat UI renders tokens live
```

**Two models required:**

| Model | Role | Size | Package |
|-------|------|------|---------|
| `all-MiniLM-L6-v2` | Text → vector embedding | ~80MB | bundled in assets |
| User-selected LLM | Answer generation (streaming) | 586MB–4.3GB | downloaded on first use |

The embedding model is always bundled. The LLM is downloaded once and stored on-device. No cloud calls ever.

---

## RAG Pipeline

### Save time — generate embedding

```
User saves a note
      ↓
EmbeddingService.embed(note.content)
      ↓
[0.12, -0.45, 0.89, ...] (384 float32 values)
      ↓
SavedNoteModel.embedding = [...] stored in Isar
```

### Query time — retrieve context

```
User types: "what did I write about relays?"
      ↓
EmbeddingService.embed(query) → query vector
      ↓
VectorSearchService:
  - load all SavedNoteModel.embedding from Isar into memory
  - for each: cosine_similarity(query_vec, note_vec)
  - sort descending, take top-K (default K=5)
      ↓
Top-K ScoredNote objects returned
```

Cosine similarity is computed in Dart. For <5,000 saved notes (typical personal user) this is fast enough without any native vector index. See `docs/rag.md` for full details.

### Baseline personalization (runs even with zero saved notes)

Before RAG context is injected, `PromptBuilder` enriches the system prompt with data already sitting in Isar — no extra network calls, no extra downloads.

| Source | What it tells Shiv | Isar model |
|--------|-------------------|------------|
| `ProfileModel` (Kind 0) | User's name and bio | `ProfileModel.about` |
| Own notes (`authorPubkey == myPubkey`) | What the user thinks and writes about | `NoteModel`, kept forever |
| `tTags` from own notes | User's topic interests (top 10 by frequency) | derived from `NoteModel.tTags` |

This means Shiv has a useful personality even on first use, before the user has saved a single note.

### Prompt assembly

```dart
final prompt = """
You are Shiv, a personal AI assistant for ${profile.name} on the UNIUN network.
${profile.about.isNotEmpty ? 'About them: ${profile.about}' : ''}
${topTags.isNotEmpty ? 'Their main interests: ${topTags.join(', ')}' : ''}

${relevantNotes.isNotEmpty ? '''
Use the notes below to answer when relevant.

--- USER NOTES ---
${relevantNotes.map((n) => '• ${n.content}').join('\n')}
--- END NOTES ---
''' : 'Answer based on general knowledge if no notes are available.'}

${conversationHistory}

User: ${userQuery}
Shiv:""";
```

`topTags` = top 10 `tTags` by frequency across all of the user's own `NoteModel` rows. Computed once per session by `PromptBuilder` and cached in memory.

### Answer streaming

`AIModelRunner` wraps `FlutterGemmaPlugin.instance.getResponseStream(prompt)` and emits tokens to `ShivAIBloc` which updates state on every token. The UI renders partial text live.

---

## Model Selection & Download

### First launch flow

When a user opens Shiv for the first time (no model downloaded):
1. `ShivPage` checks `AIModelRepository.getSelectedModel()` → null
2. Navigate to `AIModelSelectionPage`
3. User picks a model
4. Tap "Use This Model" → triggers download
5. Download progress shown with `LinearProgressIndicator`
6. On completion → `FlutterGemma.installModel().fromNetwork(url).install()` stores model internally; Isar records which `AIModelId` is active
7. `AIModelRepository` persists the selection in Isar
8. Navigate to `ShivPage` — Shiv is ready

### Model re-selection

Available from Settings → "AI Model" button (already exists in settings UI).
Same `AIModelSelectionPage` is pushed. Switching model requires re-download.
Chat history is preserved across model changes.

### Supported models (mobile — Android & iOS)

All models use `.task` (MediaPipe) or `.litertlm` (LiteRT-LM engine) format.
No HuggingFace token required. All hosted on `litert-community` public repos.

| AIModelId | Display Name | Size | Format | Thinking | Vision | Min RAM | HuggingFace Repo |
|-----------|-------------|------|--------|----------|--------|---------|-----------------|
| `qwen25_05b` | Qwen 2.5 0.5B | 0.5 GB | `.task` | ❌ | ❌ | 3 GB | `litert-community/Qwen2.5-0.5B-Instruct` |
| `deepseekR1` ⭐ | DeepSeek R1 1.5B | 1.7 GB | `.task` | ✅ | ❌ | 4 GB | `litert-community/DeepSeek-R1-Distill-Qwen-1.5B` |
| `gemma4E2b` | Gemma 4 E2B | 2.4 GB | `.litertlm` | ✅ | ✅ | 6 GB | `litert-community/gemma-4-E2B-it-litert-lm` |
| `gemma4E4b` | Gemma 4 E4B | 4.3 GB | `.litertlm` | ✅ | ✅ | 8 GB | `litert-community/gemma-4-E4B-it-litert-lm` |

**UI design reference:** `docs/ui-ux/ai_model_selection/`

The selection page groups models into three visual tiers: Lite, Balanced (pre-selected/recommended), High Performance — matching the UI mockup.

### Package

```yaml
flutter_gemma: ^0.13.1
```

Docs: https://pub.dev/documentation/flutter_gemma/latest/

---

## Branching Chat System

### What it looks like to the user

The chat looks and feels like a normal linear conversation — one message after another, top to bottom. That is the default. Branching is invisible until the user deliberately triggers it.

When the user wants to explore a different direction from an earlier point in the conversation, they long-press any previous message and choose **"Continue from here"**. From that point on, their new messages form a separate branch. The original conversation is preserved exactly as it was. The user can switch back to it at any time.

---

### The mental model (how to think about it as a developer)

Every message is a **node** in a tree. Each node knows its parent. Messages that share the same branch travel down the same path from that parent.

```
conversationId: "conv-abc"
activeBranchId: "branch-main"   ← which path the user is currently viewing

msg-1  parentId=null      branchId="branch-main"   role=user      "What is Nostr?"
msg-2  parentId=msg-1     branchId="branch-main"   role=assistant "Nostr is a protocol..."
msg-3  parentId=msg-2     branchId="branch-main"   role=user      "Tell me more about relays"
msg-4  parentId=msg-3     branchId="branch-main"   role=assistant "Relays are servers that..."

  ↑ user long-presses msg-2 → "Continue from here" → new branch created

msg-5  parentId=msg-2     branchId="branch-B"      role=user      "How does key generation work?"
msg-6  parentId=msg-5     branchId="branch-B"      role=assistant "Keys in Nostr are..."
```

In the normal chat view, the user only ever sees ONE straight path at a time. When viewing `branch-main`: msg-1 → msg-2 → msg-3 → msg-4. When viewing `branch-B`: msg-1 → msg-2 → msg-5 → msg-6. The shared messages (msg-1, msg-2) appear in both views — they are read from Isar each time.

---

### The four key fields

| Field | Where it lives | What it means |
|-------|---------------|---------------|
| `conversationId` | `ShivConversationModel` + every message | Groups all messages and branches under one conversation |
| `parentId` | Every `ShivMessageModel` | Points to the message this one follows. `null` = first message in conversation |
| `branchId` | Every `ShivMessageModel` | Groups messages that travel together on the same path. All messages in the same straight-line chain share a `branchId` |
| `activeBranchId` | `ShivConversationModel` | The branch the user is currently viewing. Loading the active chat means: walk back from the latest message in this branch, through parentIds, to the root |

---

### Data model

```dart
// ShivConversationModel (Isar)
class ShivConversationModel {
  Id id = Isar.autoIncrement;
  late String conversationId;   // unique ID for this conversation
  late String title;            // first user message, truncated to ~50 chars
  late String activeBranchId;   // which branch the user is currently on
  late DateTime createdAt;
  late DateTime updatedAt;
}

// ShivMessageModel (Isar)
class ShivMessageModel {
  Id id = Isar.autoIncrement;
  late String messageId;        // unique ID for this message
  late String conversationId;   // which conversation this belongs to
  String? parentId;             // previous message's messageId. null = first message
  late String branchId;         // which branch this message belongs to
  late MessageRole role;        // user | assistant
  late String content;
  late DateTime createdAt;
}
```

---

### Step-by-step: what happens when the user branches

**Step 1** — User long-presses msg-2 in the chat.

**Step 2** — Action sheet appears: "Continue from here" / "Cancel".

**Step 3** — User taps "Continue from here".

**Step 4** — App creates a new `branchId` (e.g. `"branch-B"`).

**Step 5** — `ShivConversationModel.activeBranchId` is updated to `"branch-B"`.

**Step 6** — The next message the user sends is saved with `parentId = msg-2.messageId` and `branchId = "branch-B"`.

**Step 7** — The chat view reloads using the active branch path (see Loading below). The user now sees: msg-1 → msg-2 → (their new message). The old path (msg-3, msg-4) is gone from view but still in Isar.

---

### Saving a message

Every new message goes into Isar as a `ShivMessageModel`. The fields to set:

```dart
final msg = ShivMessageModel()
  ..messageId   = newId()
  ..conversationId = currentConversationId
  ..parentId    = lastMessageInActiveBranch?.messageId   // null if first message
  ..branchId    = activeBranchId
  ..role        = MessageRole.user
  ..content     = userText
  ..createdAt   = DateTime.now();
```

After saving, update the conversation's `updatedAt`. If this is the first user message, also set the conversation `title` to its content (truncated to 50 chars).

---

### Loading messages for the active branch

Do NOT query by `branchId` alone — that would miss the shared messages at the root that belong to earlier branches. Instead, walk the `parentId` chain backwards from the latest message in the active branch:

```dart
// 1. Find the latest message in the active branch
final leaf = await isar.shivMessageModels
    .filter()
    .conversationIdEqualTo(convId)
    .branchIdEqualTo(activeBranchId)
    .sortByCreatedAtDesc()
    .findFirst();

// 2. Walk parentId chain back to root, collecting each message
final path = <ShivMessageModel>[];
var current = leaf;
while (current != null) {
  path.add(current);
  current = current.parentId == null
      ? null
      : await isar.shivMessageModels
          .filter()
          .messageIdEqualTo(current.parentId!)
          .findFirst();
}

// 3. Reverse to get chronological order (root → leaf)
final messages = path.reversed.toList();
```

This correctly assembles msg-1 → msg-2 → msg-5 → msg-6 for `branch-B`, even though msg-1 and msg-2 belong to `branch-main`.

---

### Branch switching — entry point and three views

All branch management happens outside the chat screen. The top-right button in the chat (`docs/ui-ux/shiv_ai_assistant/screen.png`) is the single entry point. Tapping it opens the **Conversation Graph** — a visual graph/tree system where the user can see all branches, switch between them, and create new ones.

Inside the graph system there are **two view modes** (toggled via the top-right icons in the graph screen) and **one action panel** that appears when a node is tapped. The chat itself always stays linear — branch work only happens in these views.

---

#### Entry → Conversation Graph

**Reference:** `docs/ui-ux/shiv_conversation_graph/screen.png`

This is the default view when the top-right button is tapped from chat. It shows the conversation as an interactive node graph — each branch is a node, connected by lines to its parent. The user can pan and scroll.

Top-right of this screen has **two icons**:
- 🔍 Search — find a specific branch by keyword
- 🌿 Toggle — switch between vertical tree view and full mind-map view

**Tapping any node** slides up the action panel from the bottom:

```
┌──────────────────────────────────────────┐
│  ACTIVE BRANCH  ·  Updated 2h ago  ·  12 msgs
│                                          │
│  Saga Pattern                            │  ← branch title (first user msg, truncated)
│  Implementing data consistency in        │  ← last message preview
│  distributed systems...                  │
│                                          │
│  [ Open Branch          ]                │  ← primary action
│  [ ▶  Continue From Here ]               │
│  [ +  New Branch         ]               │
└──────────────────────────────────────────┘
```

| Button | What it does in code |
|--------|----------------------|
| **Open Branch** | `conversation.activeBranchId = tappedBranch.branchId` → save to Isar → pop graph → chat reloads active path |
| **Continue From Here** | new `branchId` created → next message: `parentId = lastMessageInTappedBranch.messageId`, `branchId = newBranchId` → user picks up from the end of that branch |
| **New Branch** | new `branchId` created → next message: `parentId = tappedNode.messageId` (the node itself, not its leaf) → user starts fresh from that exact point |

---

#### View mode 1 — Vertical Tree Explorer

**Reference:** `docs/ui-ux/shiv_conversation_tree_explorer/screen.png`

Title: "AI Conversation Tree". A top-down scrollable tree. Each node is a rounded card. Curved lines connect parent to children. The active branch node is highlighted with the ★ indicator.

```
     ┌────────────────────────┐
     │  ROOT CONCEPT          │
     │  Architectural Planning│   ← root (first user message of the conversation)
     └───────────┬────────────┘
                 │
     ┌───────────┴────────────┐
     │  Microservices Strategy│   ← branch-main node (first unique msg)
     └───────────┬────────────┘
                 │
   ┌─────────────┼──────────────────┐
   ▼             ▼                  ▼
┌────────┐  ┌───────────┐  ┌──────────────┐
│ Saga ★ │  │  Event    │  │   Kub...     │
│Pattern │  │  Sourcing │  │              │
└────────┘  └───────────┘  └──────────────┘
```

- ★ = `activeBranchId` — the branch currently open in chat
- Tapping a node → opens the action panel (same as Conversation Graph)
- This is the go-to view for navigating deep, sequential conversation trees

---

#### View mode 2 — Full Mind-Map

**Reference:** `docs/ui-ux/shiv_full_conversation_tree_view/screen.png`

Title: "Conversation Tree". The same tree rendered as a horizontal mind-map. Root at the top-centre, all branches spread left/right below. Zoomable and pannable. Best for seeing the full picture at a glance.

```
                ┌──────────────────────┐
                │  ROOT CONCEPT        │
                │  Architectural       │
                │  Planning            │
                └──────────┬───────────┘
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
  ┌──────────────┐  ┌──────────┐  ┌──────────────┐
  │ Microservices│  │Deployment│  │   Security   │
  │  Strategy  ★ │  │ Options  │  │    Model     │
  └──────┬───────┘  └──────────┘  └──────────────┘
  ┌──────┼──────────────────────┐
  ▼      ▼      ▼       ▼       ▼
 Saga  Killa  Events  Serverless  Zero-Trust
```

- Tapping a node → opens the same action panel
- This view is toggled from the 🌿 icon in the Conversation Graph screen

---

### BranchTreeView — how to build the tree in code

The tree is not stored in Isar. It is **derived at render time** from the flat list of `ShivMessageModel` rows using the `parentId` → children map.

**Example conversation — raw Isar data:**

```
messageId   parentId    branchId       role        content (truncated)
─────────────────────────────────────────────────────────────────────
msg-1       null        branch-main    user        "Architectural Planning"
msg-2       msg-1       branch-main    assistant   "Here is the plan..."
msg-3       msg-2       branch-main    user        "Tell me about microservices"
msg-4       msg-3       branch-B       user        "Saga pattern"            ← branch from msg-3
msg-5       msg-4       branch-B       assistant   "Implementing data cons..."
msg-6       msg-3       branch-C       user        "Deployment options"      ← branch from msg-3
msg-7       msg-6       branch-C       assistant   "Here are your options..."
msg-8       msg-3       branch-D       user        "Security model"          ← branch from msg-3
msg-9       msg-8       branch-D       assistant   "For security consider..."
```

**Build the tree:**

```dart
// 1. Load all messages
final allMessages = await isar.shivMessageModels
    .filter()
    .conversationIdEqualTo(conversationId)
    .sortByCreatedAt()
    .findAll();

// 2. Build parentId → children lookup
final childrenOf = <String?, List<ShivMessageModel>>{};
for (final msg in allMessages) {
  childrenOf.putIfAbsent(msg.parentId, () => []).add(msg);
}

// childrenOf[null]    = [msg-1]           ← root
// childrenOf['msg-1'] = [msg-2]
// childrenOf['msg-2'] = [msg-3]
// childrenOf['msg-3'] = [msg-4, msg-6, msg-8]  ← branch point: 3 children
// childrenOf['msg-4'] = [msg-5]
// etc.
```

A node where `childrenOf[msg.messageId].length > 1` is a **branch point** — render a fork in the tree UI at that node.

**Build node labels (what appears on each card in the tree view):**

```dart
// The label for a branch node = the first user message in that branch
// that is NOT a shared root message (i.e. the message that made the branch unique)
String labelForBranch(String branchId, List<ShivMessageModel> all) {
  return all
      .where((m) => m.branchId == branchId && m.role == MessageRole.user)
      .map((m) => m.content)
      .firstOrNull
      ?.substring(0, min(30, content.length)) ?? branchId;
}
```

**Resulting tree for Screen 1 and Screen 2:**

```
ROOT CONCEPT: "Architectural Planning"   (msg-1, branch-main)
│
└── "Here is the plan..." (msg-2, shared root)
    │
    └── "Tell me about microservices" (msg-3, branch point — 3 children)
        │
        ├── branch-B ★  →  "Saga pattern"        (12 msgs)
        ├── branch-C    →  "Deployment options"  (8 msgs)
        └── branch-D    →  "Security model"      (6 msgs)
```

---

### UI rules (what the user sees)

- **Normal chat view**: flat list, top to bottom. No tree, no branches visible.
- **Branch indicator**: a small fork icon rendered on any message where `childrenOf[msg.messageId].length > 1`. Tapping it opens Screen 3 (graph panel) for that node.
- **Top-right button**: opens Screen 1 (vertical tree explorer) from the root. Reference: `docs/ui-ux/shiv_ai_assistant/screen.png`.
- **Switching branches**: instant — path walk is fast for any realistic conversation length.

---

### UX principles

- Default = looks like a normal chat. Zero branching complexity visible.
- Branching = long-press only. Never accidentally triggered.
- All branches share the same RAG context — saved notes don't change per branch.
- A branch can itself be branched from — tree depth is unlimited.

---

## Data Models

> The authoritative model definitions are in `lib/data/models/`. The snippets below show only the fields — see the Branching Chat System section for how they connect.

### ShivConversationModel (Isar)

```dart
@Collection(ignore: {'copyWith'})
@Name('ShivConversation')
class ShivConversationModel {
  Id id = Isar.autoIncrement;
  late String conversationId;   // unique ID
  late String title;            // first user message, truncated to ~50 chars
  late String activeBranchId;   // which branch path the user is currently viewing
  late DateTime createdAt;
  late DateTime updatedAt;
}
```

### ShivMessageModel (Isar)

```dart
@Collection(ignore: {'copyWith'})
@Name('ShivMessage')
class ShivMessageModel {
  Id id = Isar.autoIncrement;
  late String messageId;        // unique ID for this message
  late String conversationId;
  String? parentId;             // previous message's messageId. null = first message in conversation
  late String branchId;         // all messages on the same straight-line path share this
  @Enumerated(EnumType.name)
  late MessageRole role;        // user | assistant
  late String content;
  late DateTime createdAt;
}
```

### AIModelSelectionModel (Isar)

```dart
@Collection(ignore: {'copyWith'})
@Name('AIModelSelection')
class AIModelSelectionModel {
  Id id = Isar.autoIncrement;
  @Enumerated(EnumType.name)
  late AIModelId modelId;       // typed enum — qwen25_05b | deepseekR1 | gemma4E2b | gemma4E4b
  late String modelName;
  late String modelPath;        // modelId.name — flutter_gemma manages actual file storage
  late DateTime downloadedAt;
  late bool isActive;           // only one row can be true at a time
}
```

---

## BLoC Structure

### ShivAIBloc

Handles conversation management, inference, and branch switching. One BLoC per Shiv tab session.

**Events:**
```dart
LoadShivEvent                          // load all conversations on tab open
CreateConversationEvent                // start a new empty conversation
SelectConversationEvent(String conversationId)  // switch to an existing conversation
SendMessageEvent(String text)          // user sends a message in the active conversation
CreateBranchFromEvent(String messageId) // long-press → "Continue from here"
SwitchBranchEvent(String branchId)    // user picks a branch in BranchTreeView
DeleteConversationEvent(String conversationId)
```

**State (single class with copyWith — same pattern as ThreadState):**
```dart
ShivAIState {
  status               ShivStatus   // initial | loading | ready | streaming | error
  conversations        List<ShivConversationEntity>
  activeConversationId String?
  activeBranchId       String?
  messages             List<ShivMessageEntity>  // active branch path only (parentId walk)
  streamingText        String       // partial token text while status == streaming
  errorMessage         String?
}
```

**On SendMessageEvent:**
1. Save user message to Isar (`parentId` = last message in active branch, `branchId` = `activeBranchId`)
2. Add to `messages` in state (optimistic — UI shows immediately)
3. Build prompt: system prompt + conversation history + new user message
4. Call `AIModelRunner.generateResponse(prompt)` → stream tokens
5. Each token: `emit(state.copyWith(streamingText: accumulated))`
6. On stream complete: save assistant message to Isar, clear `streamingText`, add to `messages`

**On CreateBranchFromEvent:**
1. Generate new `branchId`
2. Update `activeBranchId` on `ShivConversationModel` in Isar
3. Reload active branch path from the tapped message onwards (empty — branch just started)
4. User's next message will use the new `branchId` and `parentId = tappedMessage.messageId`

### SelectAIModelCubit

Handles model download + selection. Lives in `lib/shiv/model_select/cubit/`.

**States:** `initial → downloading(progress: 0.0–1.0) → downloaded → active | error`

---

## UI Flow

### First open (no model)

```
ShivPage
  └─ checks AIModelRepository.getSelectedModel() → null
  └─ pushes AIModelSelectionPage
       └─ user picks model
       └─ download starts (progress bar)
       └─ on complete → pops back to ShivPage (Shiv ready)
```

### Normal chat

```
ShivPage
  ├─ ConversationListDrawer (swipe left or sidebar)
  ├─ ChatMessageList (active branch, linear)
  │   ├─ UserMessageBubble
  │   └─ ShivMessageBubble (streaming-capable)
  ├─ BranchIndicator (on messages that have branches)
  ├─ ReplyComposer (bottom)
  └─ BranchTreeButton (top-right icon)
```

### Branch tree

```
BranchTreeView (pushed as bottom sheet or full screen)
  └─ TreeNode (Root)
      ├─ TreeNode (Branch A)
      │   └─ TreeNode (Branch A.1)
      └─ TreeNode (Branch B)
  └─ tap → SwitchBranchEvent → main chat updates
```

---

## Full Build Roadmap

Build in this exact order — each step depends on the previous one being complete.

---

### Phase 1 ✅ — Model Selection (nothing works until user has a model)

**Step 1.1 — `AIModelSelectionModel` (Isar)**

File: `lib/data/models/ai_model_selection_model.dart`

What it stores: which model the user picked, where it lives on disk, when it was downloaded.

```dart
@Collection()
class AIModelSelectionModel {
  Id id = Isar.autoIncrement;
  late String modelId;       // 'qwen3_0.6b' | 'deepseek_r1' | 'gemma4_e2b' | 'gemma4_e4b'
  late String modelName;     // display name
  late String modelPath;     // modelId.name — flutter_gemma manages actual file storage
  late DateTime downloadedAt;
  late bool isActive;        // only one can be true at a time
}
```

Run `build_runner` after adding this.

---

**Step 1.2 — `AIModelRepository` interface + implementation**

Files:
- `lib/domain/repositories/ai_model_repository.dart` — interface
- `lib/data/repositories/ai_model_repository_impl.dart` — reads/writes `AIModelSelectionModel` in Isar

Key methods:
```dart
Future<Either<Failure, AIModelEntity?>> getActiveModel();
Future<Either<Failure, Unit>> saveModelSelection(AIModelEntity model);
Future<Either<Failure, Unit>> clearModelSelection();
```

---

**Step 1.3 — `SelectAIModelUseCase` + `GetSelectedModelUseCase`**

File: `lib/domain/usecases/ai_model_usecases.dart`

Simple wrappers — call repository, return Either.

---

**Step 1.4 — `SelectAIModelCubit`**

File: `lib/shiv/cubit/select_ai_model_cubit.dart`

Handles the download flow:
```
initial → downloading(progress: 0.0..1.0) → downloaded → active
                                           → error
```

Uses `flutter_gemma`'s model download API. On progress update, emits `downloading(progress)` state. UI shows a progress bar.

---

**Step 1.5 — `AIModelSelectionPage`**

File: `lib/shiv/pages/ai_model_selection_page.dart`

UI reference: `docs/ui-ux/ai_model_selection/`

Shows 4 model cards (Qwen 2.5 0.5B / DeepSeek R1 / Gemma 4 E2B / Gemma 4 E4B). Recommended badge on DeepSeek R1. "Use This Model" button starts download via `FlutterGemma.installModel()`. Progress bar while downloading.

This page is shown:
1. First time user opens Shiv (no model downloaded yet)
2. When user taps "AI Model" in Settings

---

### Phase 2 ✅ — Embedding + Vector Search + Prompt Builder (RAG complete)

**Step 2.1 — Add `embedding` field to `SavedNoteModel`**

File: `lib/data/models/saved_note_model.dart`

Add:
```dart
List<double>? embedding;   // 384 floats from all-MiniLM-L6-v2, null until generated
```

Run `build_runner` after this change.

---

**Step 2.2 — `EmbeddingService`**

File: `lib/shiv/services/embedding_service.dart`

Wraps the `all-MiniLM-L6-v2` model (bundled in app assets as a `.tflite` file).

```dart
class EmbeddingService {
  Future<void> loadModel();
  Future<List<double>> embed(String text);   // returns 384 floats
  bool get isReady;
}
```

Runs in a Dart `Isolate` — embedding is CPU-heavy and would freeze the UI if run on the main thread.

Called in two places:
- When user saves a note → `embed(note.content)` → store in `SavedNoteModel.embedding`
- When user asks Shiv a question → `embed(query)` → use for vector search

---

**Step 2.3 — `GenerateEmbeddingUseCase`**

File: `lib/domain/usecases/embedding_usecases.dart`

Called by `SaveNoteUseCase` after a note is saved. Generates the embedding and updates the `SavedNoteModel` record in Isar.

---

**Step 2.4 — Wire into `SaveNoteUseCase`**

After saving a note to Isar, call `GenerateEmbeddingUseCase` in the background (fire and forget — the user should not wait for embedding to complete before the save is confirmed).

---

### Phase 3 ✅ — Vector Search (the retrieval part of RAG)

**Step 3.1 — `VectorSearchService`**

File: `lib/shiv/services/vector_search_service.dart`

```dart
class VectorSearchService {
  // Load all embeddings from Isar into memory, compute cosine similarity, return top-K
  Future<List<ScoredNote>> search({
    required List<double> queryVector,
    required int topK,              // default 5
    double minScore = 0.3,          // ignore notes below this similarity threshold
  });
}

class ScoredNote {
  final String noteId;
  final double score;     // 0.0 (unrelated) to 1.0 (identical meaning)
  final SavedNoteEntity note;
}
```

For <5,000 saved notes this is fast enough in Dart without a native vector index.

---

**Step 3.2 — `SearchSavedNotesUseCase`**

File: `lib/domain/usecases/search_saved_notes_usecase.dart`

Input: user's query string.
Internally: embed query → vector search → return top-K notes.

---

### Phase 4 ✅ — Conversation Data (needed before building the chat UI)

**Step 4.1 — `ShivConversationModel` + `ShivMessageModel` (Isar)**

Files:
- `lib/data/models/shiv_conversation_model.dart`
- `lib/data/models/shiv_message_model.dart`

(Schemas shown in the Data Models section above.)

Run `build_runner` after adding these.

---

**Step 4.2 — Domain entities**

Files:
- `lib/domain/entities/shiv/shiv_conversation_entity.dart` (freezed)
- `lib/domain/entities/shiv/shiv_message_entity.dart` (freezed)

---

**Step 4.3 — Repositories**

Files:
- `lib/domain/repositories/shiv_conversation_repository.dart` — interface
- `lib/data/repositories/shiv_conversation_repository_impl.dart` — Isar impl
- `lib/domain/repositories/shiv_message_repository.dart` — interface
- `lib/data/repositories/shiv_message_repository_impl.dart` — Isar impl

---

**Step 4.4 — Use cases for conversations**

File: `lib/domain/usecases/shiv_conversation_usecases.dart`

```dart
CreateConversationUseCase   → creates new ShivConversationModel in Isar
LoadConversationUseCase     → loads messages for a conversation (active branch path)
SaveMessageUseCase          → saves a user or assistant message
SwitchBranchUseCase         → updates activeBranchId on the conversation
CreateBranchUseCase         → creates a new branch from a given parentId message
```

---

### Phase 5 ✅ — Prompt Builder

**Step 5.1 — `PromptBuilder`**

File: `lib/shiv/services/prompt_builder.dart`

Takes: top-K relevant notes + branch conversation history + current user question.
Returns: assembled prompt string ready to send to the LLM.

```dart
String build({
  required List<ScoredNote> relevantNotes,
  required List<ShivMessageEntity> history,
  required String userQuestion,
  int maxTokens = 2048,       // leave room for LLM response
});
```

Truncates notes if the total prompt would exceed `maxTokens`. Most important notes go in first.

---

### Phase 6 — AI Model Runner

**Step 6.1 — `AIModelRunner`**

File: `lib/shiv/services/ai_model_runner.dart`

Wraps `flutter_gemma`:

```dart
class AIModelRunner {
  Future<void> loadModel(String modelPath);
  Stream<String> run(String prompt);    // streams tokens
  Future<void> unloadModel();
  bool get isReady;
}
```

Internally: `FlutterGemmaPlugin.instance.getResponseStream(prompt)`.

---

### Phase 7 — ShivAIBloc

**Step 7.1 — `ShivAIBloc`**

File: `lib/shiv/bloc/shiv_ai_bloc.dart`

This is the main wiring piece. On `SendMessageEvent`:
1. Save user message to Isar (`SaveMessageUseCase`)
2. Embed user question (`EmbeddingService`)
3. Find relevant notes (`VectorSearchService`)
4. Build prompt (`PromptBuilder`)
5. Stream tokens from LLM (`AIModelRunner`)
6. On each token: emit `ShivAIState` with updated `streamingText`
7. On stream complete: save assistant message to Isar (`SaveMessageUseCase`)

Events, state, and BLoC structure defined in the BLoC Structure section above.

---

### Phase 8 — Chat UI

**Step 8.1 — `ShivPage`**

File: `lib/shiv/pages/shiv_page.dart`

On build:
- Check `AIModelRepository.getActiveModel()` → if null, push `AIModelSelectionPage`
- Otherwise show chat UI

**Step 8.2 — Chat widgets**

Files in `lib/shiv/widgets/`:
- `shiv_message_bubble.dart` — user vs assistant bubble, streaming-aware (shows partial text while `status == streaming`)
- `shiv_reply_composer.dart` — text input + send button at bottom
- `branch_indicator.dart` — small icon on messages that have been branched from
- `branch_tree_view.dart` — tree visualization for switching branches (bottom sheet)
- `conversation_list_drawer.dart` — sidebar listing all past conversations

**Step 8.3 — Settings wire-up**

Settings already has an "AI Model" button. Wire it to push `AIModelSelectionPage`.

File to update: `lib/settings/pages/settings_page.dart`

---

### Build Order Summary (updated)

```
Phase 1 ✅  Model Selection
            AIModelSelectionModel → AIModelRepository → SelectAIModelCubit → AIModelSelectionPage
            AppSettingsModel singleton stores active model choice.
            ShivPage redirects to selection screen if no model is active.

Phase 2 ✅  Chat UI + Inference
            ShivConversationModel + ShivMessageModel (parentId linked-list for future branching)
            → ShivConversationEntity + ShivMessageEntity
            → ShivRepository interface + ShivRepositoryImpl
            → shiv_usecases.dart (GetConversations, CreateConversation, DeleteConversation,
              GetMessages, SaveMessage, UpdateMessageContent, UpdateConversationTitle,
              UpdateActiveLeaf)
            → AIModelRunner (InferenceChat wrapper — flutter_gemma 0.13.x)
            → ShivAIBloc (LoadConversations, CreateConversation, OpenConversation,
              SendMessage, TokenReceived, StreamDone, StreamError, DeleteConversation)
            → ShivChatPage + ShivMessageBubble + ShivInputComposer
            → ShivHistoryDrawer (Scaffold side drawer) + ShivConversationTile
            → ShivPage landing + model check
            Auto-title: first 40 chars of first user message → UpdateConversationTitleUseCase

Phase 3 ✅  RAG — Embedding + Vector Search + Prompt Builder
            NoteModel.embedding field (List<double>?, stored in Isar)
            → EmbeddingService (all-MiniLM-L6-v2 via tflite_flutter, ~80MB TFLite model)
            → VectorSearchService (cosine similarity, brute-force top-K over saved notes)
            → PromptBuilder (buildSystemInstruction: persona + user name/bio/interests;
              buildUserMessage: RAG context + question)
            → RagPipeline orchestrator (two-phase: init() once per session,
              buildMessage() per turn)
            System instruction prepended to first user turn (Qwen templates ignore
            createChat(systemInstruction:) — confirmed by flutter_gemma logs).

Phase 4 🔲  Branching Graph View  
            BranchTreeView (AI Conversation Tree — vertical explorer)
            → Full Mind-Map view (zoomable)
            → Conversation Graph node-tap panel (Open Branch / Continue From Here / New Branch)
            → CreateBranchFromEvent in ShivAIBloc
            → SwitchBranchEvent in ShivAIBloc
            parentId chain in ShivMessageModel already supports this — no schema change needed.
```

Each phase depends on the previous being complete.

---

## What Is NOT in v1

| Feature | Status | Notes |
|---------|--------|-------|
| GraphRAG (graph traversal via `eTagRefs`) | Deferred | Designed — see `docs/graphrag.md`. Adds multi-hop context. Post-MVP. |
| Image/audio understanding | Deferred | Gemma 4 E2B/E4B supports it, RAG pipeline is text-only for now |
| Cloud/API model option | Never | Everything is on-device. No API keys ever. |
| Conversation export | Future | Nice to have |
| Semantic search in feed | Future | Currently only saved notes are embedded |


---

# ✅ What you ALREADY have (good foundation)

From your system: 

* ✔ Embedding (MiniLM)
* ✔ Storage (Isar)
* ✔ Retrieval (cosine similarity, brute force)
* ✔ Prompt building
* ✔ LLM response (Gemma)

👉 This is called **Basic RAG (Naive RAG)**

---

# 🚨 What will break as data grows (VERY IMPORTANT)

When notes → **100 → 1K → 10K → 100K**

### Problems you’ll hit:

1. 🐢 **Search becomes slow**

   * You loop through ALL notes (O(N))
2. 🎯 **Relevance drops**

   * Top-5 may miss important context
3. 🧠 **Context overload**

   * Too many notes → LLM gets confused
4. 🔗 **No relationships**

   * Notes are isolated (no connections)
5. 📄 **Large notes problem**

   * One note = too big → embedding loses detail

---

# 🚀 What ADVANCED RAG systems add (future roadmap)

This is what you can implement step by step 👇

---

## 1. ⚡ ANN (Fast Vector Search) — MUST HAVE

👉 Replace brute-force search

### Your current:

```text
for each note → compute similarity ❌ slow
```

### Upgrade:

* FAISS / HNSW / tostore

👉 Complexity:

```text
O(N) → O(log N)
```

✔ Handles 100K+ notes easily
✔ Already mentioned in your doc as future step

---

## 2. ✂️ Chunking (VERY IMPORTANT)

Right now:

```text
1 note = 1 embedding ❌
```

Problem:

* Large note → loses meaning

### Fix:

```text
1 note → split into chunks
```

Example:

```text
Note:
"Flutter performance tips..."

→ Chunk 1
→ Chunk 2
→ Chunk 3
```

✔ Better retrieval accuracy
✔ Standard in all RAG systems

---

## 3. 🧠 Hybrid Search (Keyword + Vector)

Right now:

```text
only semantic search
```

Problem:

* Misses exact keywords

### Upgrade:

```text
Vector search + keyword search (BM25)
```

✔ Best of both:

* meaning + exact match

---

## 4. 🔗 GraphRAG (YOU ALREADY PLANNED THIS 🔥)

You already mentioned:

```text
BFS on eTagRefs + tTags
```

👉 This is NEXT LEVEL

### Why important:

Instead of:

```text
find similar notes
```

You do:

```text
find related notes → expand graph
```

✔ Multi-hop reasoning
✔ Better context

---

## 5. 🎯 Re-ranking (VERY powerful)

Right now:

```text
topK by cosine similarity
```

Problem:

* similarity ≠ best answer always

### Upgrade:

```text
Top 20 → re-rank using LLM / cross-encoder → pick best 5
```

✔ Much better accuracy

---

## 6. 🧩 Context Optimization

Right now:

```text
just dump top-5 notes into prompt
```

Problem:

* noisy context
* token waste

### Upgrade:

* summarize notes
* remove duplicates
* compress context

---

## 7. 🔄 Query Transformation

Before search:

```text
user: "fix bug"
```

Upgrade:

```text
→ rewrite query: "how to debug flutter apps"
```

✔ Better retrieval

---

## 8. 🧠 Caching (performance boost)

* cache embeddings
* cache search results

✔ avoids recomputation

---

## 9. 📊 Metadata Filtering

Use:

* tags
* timestamps
* categories

```text
search only in "flutter" notes
```

✔ faster + more relevant

---

## 10. 🧪 Evaluation system (advanced)

Measure:

* retrieval accuracy
* answer quality

✔ needed for scaling

---

# 🧱 Final Architecture (Future)

```text
User Query
   ↓
Query Rewrite
   ↓
Embedding
   ↓
ANN Search (fast)
   ↓
Graph Expansion (GraphRAG)
   ↓
Re-ranking
   ↓
Context Compression
   ↓
Prompt Builder
   ↓
LLM
```



# 🔥 Final simple understanding

👉 Your current system = **basic brain (good memory)**
👉 Advanced RAG = **brain + indexing + relationships + filtering**

---

# 💡 One-line takeaway

👉 You are DONE with **basic RAG**,
next level is about **scaling + improving retrieval quality**, not just embedding.

---

