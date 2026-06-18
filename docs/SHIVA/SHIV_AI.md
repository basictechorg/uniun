# Shiv AI — System Design

Shiv is UNIUN's AI assistant. It reasons over the user's saved notes via vector + graph RAG, and runs against **two interchangeable backends** behind one repository:

- **Local** — `flutter_gemma 0.16.5` on-device inference (default, fully offline).
- **Cloud** — OpenRouter via `openrouter_api 1.0.2` (one key, every major frontier model).

The user picks the backend in Settings. The chat code, RAG pipeline, knowledge extractor and BLoC have **no idea which backend is active** — they call the same `LlmRepository` interface.

Resources: <https://pub.dev/packages/flutter_gemma> · <https://pub.dev/documentation/flutter_gemma/latest/> · <https://openrouter.ai/docs>

---

## Table of Contents

1. [Mental Model](#mental-model)
2. [Clean Architecture Layers](#clean-architecture-layers)
3. [File-by-File Map](#file-by-file-map)
4. [Call Flows](#call-flows)
5. [Backend Switching — Local ↔ Cloud](#backend-switching--local--cloud)
6. [Branching Chat](#branching-chat)
7. [RAG Pipeline](#rag-pipeline)
8. [Data Models](#data-models)
9. [Out of Scope](#out-of-scope)

---

## Mental Model

```
ShivChatPage (or any caller — extraction, summarisation, …)
        │
        ▼
ShivAIBloc / ExtractKnowledgeUseCase           ← Presentation / Domain
        │  calls *.call(input) — never an engine directly
        ▼
llm_usecases.dart                              ← Domain use cases
   SendChatStreamUseCase / GenerateOneShotUseCase / …
        │
        ▼
LlmRepository  (interface)                     ← Domain contract
        │
        ▼
LlmRepositoryImpl                              ← Data layer dispatcher
        │  reads LlmPreferencesDataSource.activeBackend, picks one of:
        ├──────────────────────────────────────────────┐
        ▼                                              ▼
LocalLlmDataSource                            RemoteLlmDataSource
        │                                              │
        ▼                                              ▼
AIModelRunner ▶ openChat(modelType…)         OpenRouterInference
        │  ModelTaskQueue (high / low lanes)           │  Dio + SSE stream
        ▼                                              ▼
flutter_gemma 0.16.5 (LiteRT-LM / MediaPipe)  openrouter.ai REST API
```

Two things to notice:

1. **One contract, two paths.** `LocalLlmDataSource` and `RemoteLlmDataSource` both implement `LlmDataSource`. The repository picks based on `LlmPreferencesDataSource.activeBackend`.
2. **The runner is internal.** `AIModelRunner` is no longer a service — it's an implementation detail of `LocalLlmDataSource`, sitting at `lib/data/datasources/llm/local_llm_runner.dart`. Phase 1 of the v2 refactor moved it out of `lib/features/shiv/services/` so the layer boundary is honest.

---

## Clean Architecture Layers

Strict downward calls. Presentation never imports `flutter_gemma`. Data never imports widgets.

| Layer | Path | Contents |
|---|---|---|
| **Presentation** | `lib/features/shiv/` | `ShivAIBloc`, pages, widgets, model picker sheet |
| **Presentation** | `lib/features/settings/widgets/` | `CloudProviderCard` (API key paste + backend toggle) |
| **Domain — entities** | `lib/domain/entities/llm/` | `LlmBackendType`, `LlmModelInfo` |
| **Domain — repositories** | `lib/domain/repositories/` | `LlmRepository`, `LlmCredentialsRepository` |
| **Domain — use cases** | `lib/domain/usecases/llm_usecases.dart` | 14 use cases grouped per SRP — chat, one-shot, lifecycle, backend, credentials |
| **Core primitives** | `lib/core/llm/` | `LlmCancellationToken` |
| **Data — repositories** | `lib/data/repositories/` | `LlmRepositoryImpl`, `LlmCredentialsRepositoryImpl` |
| **Data — data sources** | `lib/data/datasources/llm/` | Both backends + runner + queue + prefs + credentials store |

---

## File-by-File Map

### Domain — entities

```
lib/domain/entities/llm/
├── llm_backend_type.dart    enum { localGemma, openRouter }
└── llm_model_info.dart      @freezed { id, displayName, backend, contextWindow, prices… }
```

### Domain — repositories (interfaces only)

```
lib/domain/repositories/
├── llm_repository.dart              session lifecycle + sendChat + generateOneShot
│                                    + preempt/resume + backend & model selection
├── llm_credentials_repository.dart  save/clear/get OpenRouter key
└── ai_model_repository.dart         (existing) local model catalog + download
                                     ←— kept as-is; manages files on disk, not inference
```

### Domain — use cases (grouped — `llm_usecases.dart`)

| Class | Wraps |
|---|---|
| `HasActiveLlmModelUseCase` | `LlmRepository.hasActiveModel()` |
| `OpenLlmConversationUseCase` | `openConversation(systemInstruction)` |
| `CloseLlmConversationUseCase` | `closeConversation()` |
| `SendChatStreamUseCase` | `sendChat(message, cleanHistory)` → `Stream<String>` |
| `GenerateOneShotUseCase` | `generateOneShot(prompt, maxTokens)` |
| `PreemptBackgroundWorkUseCase` | pauses low-priority lane (chat is incoming) |
| `ResumeBackgroundWorkUseCase` | resumes low-priority lane |
| `GetActiveLlmBackendUseCase` / `SetActiveLlmBackendUseCase` | local ↔ cloud switch |
| `ListAvailableLlmModelsUseCase` | local: downloaded models · cloud: OpenRouter catalogue |
| `GetActiveLlmModelUseCase` / `SetActiveLlmModelUseCase` | which model is active on the active backend |
| `SaveOpenRouterKeyUseCase` / `ClearOpenRouterKeyUseCase` / `HasOpenRouterKeyUseCase` | credential mgmt |

### Core primitives

```
lib/core/llm/
└── llm_cancellation_token.dart    Completer-backed cancel signal
```

### Data — repositories

```
lib/data/repositories/
├── llm_repository_impl.dart            dispatches per active backend
└── llm_credentials_repository_impl.dart  thin wrapper over secure storage
```

### Data — data sources (the heart of the engine routing)

```
lib/data/datasources/llm/
├── llm_data_source.dart             abstract — one impl per backend
│
├── local_llm_data_source.dart       wraps AIModelRunner + ModelTaskQueue
│                                    listAvailableModels → local catalog (downloaded only)
│
├── local_llm_runner.dart            opens InferenceChat via flutter_gemma 0.16
│                                    passes modelType + isThinking per active model
│                                    holds _activeExtraction → safe preemption
│
├── local_inference_queue.dart       high/low priority lanes
│                                    pauses low while user is in Shiv tab
│
├── local_model_params.dart          AIModelId → (ModelType, isThinking) lookup
│                                    keeps chat template aligned to the model file
│
├── remote_llm_data_source.dart      OpenRouterInference wrapper
│                                    Stream<String> from streamCompletion()
│                                    preempts active extraction sub on chat send
│
├── llm_credentials_data_source.dart flutter_secure_storage for the OpenRouter key
│                                    (same Keystore/Keychain pattern as nsec)
│
└── llm_preferences_data_source.dart SharedPreferences: activeBackend + activeCloudModelId
```

### Presentation — Shiv feature

```
lib/features/shiv/
├── pages/shiv_page.dart                       tab root: model check → landing / chat
├── chat/
│   ├── bloc/shiv_ai_bloc.dart                 events, state, streaming, branching
│   ├── pages/shiv_chat_page.dart              message list + composer
│   ├── widgets/
│   │   ├── shiv_message_bubble.dart           user/assistant bubbles, <think> parsing
│   │   ├── shiv_input_composer.dart           [+ model picker] + text field + send/stop
│   │   ├── shiv_history_drawer.dart           conversation list side drawer
│   │   ├── shiv_conversation_tile.dart        swipe-to-delete tile
│   │   └── shiv_model_picker_sheet.dart       + button → bottom-sheet model picker
│   └── tree/                                  branch graph view (long-press fork)
├── model_select/                              SelectAIModelCubit + AIModelSelectionPage
│                                              (local file catalog — Phase 1 unchanged)
└── rag/
    ├── embedding/embedding_service.dart       all-MiniLM-L6-v2 (tflite_flutter)
    ├── retrieval/vector_search_service.dart   cosine sim over ToStore vectors
    ├── prompt/prompt_builder.dart             system prompt + extraction prompt
    ├── prompt/prompt_budget.dart              per-model token budgets
    └── pipeline/rag_pipeline.dart             init + buildMessage (two-phase)
```

### Presentation — Settings

```
lib/features/settings/
├── pages/settings_page.dart                Account · Identity · AI · Cloud AI · Storage · …
└── widgets/
    ├── ai_card.dart                        opens local model picker (AIModelSelectionPage)
    └── cloud_provider_card.dart            paste OpenRouter key, switch backend, disconnect
```

---

## Call Flows

### Chat send — happy path

```
User taps send in ShivChatPage
   │
   ▼
ShivAIBloc._onSendMessage
   │  saves user msg + placeholder asst msg to Isar
   │
   ▼
RagPipeline.buildMessage(userQuestion)                  ← see "RAG per turn" below
   │  • picks PromptBudget.forActiveModel(getActiveLlmModel)
   │  • embed query → vector search → graph expand → memory lookup
   │  • PromptBuilder.buildUserMessage(enriched, budget) → final prompt string
   │
   ▼  RagMessage { userMessage, contextCount }
_sendChatStream.call(SendChatStreamInput(message: userMessage, cleanHistory))
   │
   ▼
SendChatStreamUseCase  →  LlmRepository.sendChat
   │
   ▼
LlmRepositoryImpl._active  ← reads prefs.activeBackend
   │
   ├─ localGemma  ─►  LocalLlmDataSource.sendChat
   │                     │
   │                     ▼  AIModelRunner.sendAndStream
   │                     │     • _activeExtraction?.stopGeneration()   safe per-session preempt
   │                     │     • _queue.runHigh<void>(…)
   │                     │     • model.openChat(modelType, isThinking) ← from LocalModelParams
   │                     │     • chat.addQueryChunk(Message.text(prompt))
   │                     │     • generateChatResponseAsync() → yields TextResponse tokens
   │                     ▼  Stream<String>
   │
   └─ openRouter  ─►  RemoteLlmDataSource.sendChat
                         │
                         │  cancel any in-flight _extractionSub
                         │  OpenRouterInference.streamCompletion(modelId, messages)
                         ▼  map(r → r.choices.first.content) → Stream<String>
```

The stream returns to `_onTokenReceived` (strips leading whitespace, appends to `streamingContent`). `_onStreamDone` persists the final asst message and strips any `<think>…</think>` blocks.

### RAG per turn — what happens inside `RagPipeline.buildMessage`

```
userQuestion: "what did i write about the saga pattern?"
       │
       ▼
[1] EmbeddingService.embed(query)
       │  all-MiniLM-L6-v2 (tflite_flutter, on-device, ~80 MB)
       ▼  List<double> queryVec (384 dims)
       │
[2] PromptBudget.forActiveModel(LlmModelInfo)
       │  Qwen3 0.6B  → max=2048,  topK=3,  hops=1
       │  Gemma 4 E4B → max=8192,  topK=10, hops=2
       │  Cloud       → max=16384, topK=15, hops=2
       ▼  PromptBudget { maxTokens, topK, maxHops, section caps }
       │
[3] VectorSearchService.search(queryVec, topK=budget.topK)
       │  ToStore ANN cosine over saved-note embeddings
       ▼  List<ScoredNote>  seedNotes
       │
[4] GetMemoriesByNoteIdsUseCase(seedNoteIds)
       │  pulls MemoryNodeModel rows the extractor built earlier
       ▼  seedMemories + concept keys
       │
[5] GetGraphNeighboursUseCase(conceptKeys, maxHops=budget.maxHops)
       │  BFS over GraphEdgeModel from seed concepts
       ▼  edges (each = source → relation → target)
       │
[6] GetGraphNodesByKeysUseCase(edge endpoints)
       │  resolves keys to readable node names
       ▼  graphNodes
       │
[7] GetMemoriesByNoteIdsUseCase(notes that asserted those edges)
       │  expandedMemories from beyond the seeds
       ▼  EnrichedContext { seedNotes, graphNodes, graphEdges, memories }
       │
[8] PromptBuilder.buildUserMessage(enriched, budget)
       │  Lays out as: "Question: <q>" → context sections → "## Question\n<q>"
       │  (question repeated at both ends — Lost-in-the-Middle countermeasure
       │  from Liu et al. 2023; small models attend strongest to start + end).
       │
       │  Priority order — drops lowest first if over budget:
       │    query (10%)  →  top 1-2 seed notes (35%)
       │                 →  graph relations (20%)
       │                 →  remaining seed notes
       │                 →  memory summaries (15%)
       ▼  String userMessage
       │
   RagMessage { userMessage, contextCount = #notes + #edges + #memories }
```

The exact same `RagMessage` is sent to whichever LLM is active — local Gemma or cloud OpenRouter. RAG is backend-agnostic. The embedding always runs on-device, so even cloud chat doesn't leak the note bodies it didn't pull into context.

Pipeline source: `lib/features/shiv/rag/pipeline/rag_pipeline.dart` — `buildMessage` (per turn) + `buildSystemInstruction` (once at conversation open).

### Knowledge extraction — background graph build

```
VishnuFeedBloc / ThreadConversationBody save action
   │
   ▼
SaveNoteUseCase + (fire-and-forget) EmbedAndStoreNoteUseCase
   │
   ▼
EmbedAndStoreNoteUseCase  ─►  ExtractKnowledgeUseCase
   │
   │  hasModel = await HasActiveLlmModelUseCase.call()
   │  searchVectors → similar notes for context
   │  builds extraction prompt (directional, JSON schema)
   ▼
GenerateOneShotUseCase  →  LlmRepository.generateOneShot
   │
   ├─ local  ─►  AIModelRunner.generateOneShot
   │                _queue.runLow<>(…)         ← yields to chat
   │                model.openChat(temp=0.2)
   │                _activeExtraction = oneShot  ← held so chat can stopGeneration()
   │                → buffer concatenated tokens → String?
   │
   └─ cloud  ─►  RemoteLlmDataSource.generateOneShot
                    streamCompletion → buffer → String?
                    _extractionSub held for preemption

Parsed JSON → graph nodes + edges + memory upserted in Isar.
```

If chat preempts during local extraction: `stopGeneration()` cancels the extraction session (safe in 0.16 — `openChat` gives independent native sessions). Extraction returns `null`. The pending row in `PendingExtractionRepository` survives, and `DrainPendingExtractionsUseCase` retries it when the user leaves the Shiv tab.

### Enter / leave Shiv tab

```
HomePage tab index → 2
   ▼
ShivAIBloc.onEnterShivTab()
   ▼
PreemptBackgroundWorkUseCase  →  LlmRepository.preemptBackgroundWork
   │
   ├─ local: ModelTaskQueue.pauseLowPriority()  (running extraction allowed to finish)
   └─ cloud: cancels _extractionSub
```

Leaving the tab does the inverse plus `DrainPendingExtractionsUseCase.call()` to replay any preempted extractions.

### Connect cloud provider

```
SettingsPage → CloudProviderCard → "Connect API key"
   │  user pastes sk-or-…
   ▼
SaveOpenRouterKeyUseCase  →  LlmCredentialsRepositoryImpl
   │  writes secure storage; invalidates cached OpenRouterInference
   ▼
ListAvailableLlmModelsUseCase  ←  validates the key by calling listModels()
   │
   ├─ ok   → card flips to Connected
   └─ fail → ClearOpenRouterKeyUseCase + snackbar
```

### Switch backend

```
CloudProviderCard toggle (or model picker sheet — not yet wired there)
   ▼
SetActiveLlmBackendUseCase  →  LlmRepository.setActiveBackend(openRouter)
   │  refuses if no API key configured → returns Failure
   ▼
LlmPreferencesDataSource.setActiveBackend
   │  (next call to LlmRepositoryImpl._active resolves to RemoteLlmDataSource)
```

### Pick a model (chat input `+`)

```
ShivInputComposer + icon → ShivModelPickerSheet
   ▼
ListAvailableLlmModelsUseCase   (local: downloaded · cloud: OpenRouter catalogue)
   │
   ▼ user taps a row
SetActiveLlmModelUseCase  →  LlmRepository.setActiveModel(id)
   │  local  → AppSettingsStore.setActiveModelId(AIModelId.values.byName(id))
   └─ cloud → LlmPreferencesDataSource.setActiveCloudModelId(id)
```

---

## Backend Switching — Local ↔ Cloud

| Concern | Local Gemma | Cloud OpenRouter |
|---|---|---|
| Trigger | Default; user has a model downloaded | User pastes API key + flips toggle |
| Inference path | flutter_gemma `openChat` → `addQueryChunk` → `generateChatResponseAsync` | OpenRouter REST `streamCompletion` (SSE) |
| Session model | Per-turn `openChat` with `modelType` from `LocalModelParams` | Stateless — full prompt every call |
| Cancellation | per-session `stopGeneration()` (safe since 0.16; KV-cache bleed between sequential `openChat`s fixed in 0.16.5) | cancel the Dio `StreamSubscription` |
| Concurrency | accelerator-mutexed → `ModelTaskQueue` high/low lanes | network-concurrent — no queue |
| Preemption of extraction | `_activeExtraction.stopGeneration()` before chat enters high lane | cancel `_extractionSub` |
| Models exposed | downloaded local files (via `AIModelRepository`) | live `OpenRouter.listModels()` |
| Credentials | none | `flutter_secure_storage` (Android Keystore / iOS Keychain) |

### Chat template safety (a v2 fix worth highlighting)

`openChat()` defaults `modelType` to `gemmaIt`. If we don't override it, the SDK renders a Gemma 2/3 template even when the loaded file is Qwen3 or Gemma 4 → garbled prompts, leading `\n` tokens, hallucinations.

`LocalModelParams.forId()` is the **single source of truth** for the runtime mapping:

```
qwen25_05b   →  ModelType.qwen3   isThinking=false   (we use Qwen3 0.6B today)
deepseekR1   →  ModelType.deepSeek isThinking=true
gemma4E2b    →  ModelType.gemma4   isThinking=false
gemma4E4b    →  ModelType.gemma4   isThinking=false
```

The same mapping exists in `AIModelRepositoryImpl._gemmaParams` for the *install* path. Both must stay in sync — runtime template and install spec must agree.

### Logging in release (privacy)

`flutter_gemma` 0.16.5 gates every internal log on `kDebugMode`. Release builds are silent regardless of level — no prompt, output, or conversation history can reach `logcat` / `syslog` even if a user (or attacker) tries to enable verbose mode.

`lib/main.dart` still sets the level explicitly so the *intent* is on the page:

```dart
FlutterGemma.logLevel =
    kReleaseMode ? GemmaLogLevel.none : GemmaLogLevel.info;
```

Use `GemmaLogLevel.verbose` only when actively debugging a model bug locally — it prints prompts and generated tokens.

### KV-cache hygiene

Before 0.16.5, opening a new chat after closing one could see residual KV-cache state from the previous native session (issue #308). Fixed upstream: each `createSession` now opens a fresh native session + conversation handle. We get this for free with the version bump — no code change needed.

---

## Branching Chat

The chat looks linear by default. Long-press a message → "Continue from here" forks a branch. The branch tree is **derived at render time** from `ShivMessageModel.parentId` — no separate branch table.

### Four fields that drive everything

| Field | Where | Meaning |
|---|---|---|
| `conversationId` | `ShivConversationModel` + every msg | groups everything under one conversation |
| `parentId` | `ShivMessageModel` | predecessor message — `null` for root |
| `activeLeafMessageId` | `ShivConversationModel` | which path the user is currently viewing |
| `messageId` | `ShivMessageModel` | unique per message |

### Loading the active path

Walk `parentId` backwards from `activeLeafMessageId` to root, reverse, render. The shared root messages naturally appear in every branch — no duplication on disk.

```dart
final byId = {for (final m in all) m.messageId: m};
final path = <ShivMessageEntity>[];
String? cur = activeLeafMessageId;
while (cur != null) { path.insert(0, byId[cur]!); cur = byId[cur]!.parentId; }
```

### Branch view modes

- **Vertical Tree Explorer** — `lib/features/shiv/chat/tree/pages/shiv_branch_tree_page.dart`
- **Node action panel** — `lib/features/shiv/chat/tree/widgets/node_action_panel.dart` (Open / Continue From Here / New Branch)
- **Branch graph** — `lib/features/shiv/chat/tree/widgets/branch_tree_graph.dart`

---

## RAG Pipeline

Two-phase to match `InferenceChat`'s lifecycle:

**Phase 1 — session open (once per conversation):**
```dart
await rag.init();                                  // load embedding model
final sysInstruction = await rag.buildSystemInstruction();   // persona + name + bio
await openConv.call(OpenLlmConversationInput(systemInstruction: sys));
```

**Phase 2 — each user turn:**
See the [RAG per turn](#rag-per-turn--what-happens-inside-ragpipelinebuildmessage) flow above for the step-by-step inside `buildMessage`. Output is a single `RagMessage { userMessage, contextCount }` that gets passed verbatim to `SendChatStreamUseCase`.

### Per-model RAG scaling

`PromptBudget.forActiveModel(LlmModelInfo)` resolves the budget each turn — RAG automatically grows or shrinks to match the active engine's context window. Caller does nothing special.

| Active model | RAG budget | topK seed notes | graph hops | Engine `maxTokens` |
|---|---:|---:|---:|---:|
| Qwen3 0.6B (default small) | 2,048 | 3 | 1 | 2,048 |
| DeepSeek R1 1.5B | 1,024 | 3 | 1 | 1,280 |
| Gemma 4 E2B | 4,096 | 5 | 2 | 4,096 |
| Gemma 4 E4B | 8,192 | 10 | 2 | 8,192 |
| **Cloud (OpenRouter)** | **16,384** | **15** | **2** | — |
| no active model | 2,048 | 3 | 1 | — |

Engine `maxTokens` is the hard KV-cache size baked into the local model file (e.g. `deepseek_q8_ekv1280.task` = 1,280-token cache; opening larger aborts at `CalculatorGraph::Run`). RAG budget for DeepSeek therefore reserves ~256 tokens for the generated response.

Cloud's 16k cap is intentional — most cloud models expose 32k–1M context but pulling too much makes answers noisier *and* costs more. `openrouter_api 1.0.2` doesn't expose `LlmModel.contextWindow` yet; when it does, `_cloud()` will read it and adapt per-model.

Section split inside any budget: query 10%, top notes 35%, graph relations 20%, summaries 15%. Trimming order (drops lowest first): summaries → extra seed notes → graph relations.

### Chat history budget (separate from RAG budget)

RAG sections compete inside `PromptBudget`; chat history is budgeted **separately** inside `LocalLlmRunner` so old turns can't eat into the RAG context. On every call to `sendAndStream`:

```dart
historyBudgetTokens = (LocalModelParams.maxTokens × 0.20).round()
```

| Active model | History budget |
|---|---:|
| Qwen3 0.6B | ~410 |
| DeepSeek R1 1.5B | ~256 |
| Gemma 4 E2B | ~820 |
| Gemma 4 E4B | ~1,640 |

`_trimHistory` walks `cleanHistory` newest-first and keeps as many `(user, assistant)` pairs as fit, restoring chronological order before composing the prompt. Older turns are silently dropped — the LLM never sees them. The current question is always preserved (it's a separate `currentMessage` arg, not part of the history budget). Why 20%: leaves 80% for system instruction + RAG sections + response — empirically the sweet spot for keeping multi-turn coherence on small models without starving retrieval.

Source: `lib/data/datasources/llm/local_llm_runner.dart` — `_historyBudgetTokens`, `_trimHistory`, `_composePrompt`.


### Embedding stays local even on cloud backend

`all-MiniLM-L6-v2` (~80 MB, bundled `.tflite`) runs in `EmbeddingService` regardless of which LLM is active. The embedding is independent of the answer generator — local notes, local vectors, then *either* on-device or cloud LLM consumes the assembled prompt. No private data ever leaves the device unless the user explicitly chose the cloud backend.

### Extraction prompt (directional rule landed v2)

`prompt_builder.dart:buildExtractionPrompt` now enforces "<source> <type> <target>" reads as a sentence, with a worked example that prevents the inverted-edge bug ("rajendrasinh is_son_of samarth" wrong; "samarth child_of rajendrasinh" right).

---

## Data Models

> Authoritative definitions live in `lib/data/models/`. Below is the schema shape only.

```dart
// lib/data/models/shiv_conversation_model.dart
class ShivConversationModel {
  Id id = Isar.autoIncrement;
  late String conversationId;
  late String title;                  // first user msg truncated to 40 chars
  late String activeLeafMessageId;    // walks parentId chain to render branch
  late DateTime createdAt;
  late DateTime updatedAt;
}

// lib/data/models/shiv_message_model.dart
class ShivMessageModel {
  Id id = Isar.autoIncrement;
  late String messageId;
  late String conversationId;
  String? parentId;                   // null = root
  @Enumerated(EnumType.name) late MessageRole role;   // user | assistant
  late String content;
  late DateTime createdAt;
}

// lib/data/models/ai_model_selection_model.dart
class AIModelSelectionModel {
  Id id = Isar.autoIncrement;
  @Enumerated(EnumType.name) late AIModelId modelId;
  late String modelName;
  late String modelPath;              // modelId.name — flutter_gemma owns the file
  late DateTime downloadedAt;
}

// lib/data/models/memory_node_model.dart    (GraphRAG wiki summary per note)
// lib/data/models/graph_node_model.dart     (extracted concept)
// lib/data/models/graph_edge_model.dart     (extracted relation, subject → verb → object)
```

The active backend (`localGemma` / `openRouter`) and the active cloud model id live in `SharedPreferences` (via `LlmPreferencesDataSource`), not in Isar.

API keys live **only** in `flutter_secure_storage` (via `LlmCredentialsDataSource`), never in Isar or SharedPreferences.

### Local model catalog

All four files come from the `litert-community` org on HuggingFace — the same source flutter_gemma's own README recommends. No HuggingFace token required.

| AIModelId | Display | Size | Format | ModelType | isThinking |
|---|---|---|---|---|---|
| `qwen25_05b` | Qwen3 0.6B | 586 MB | `.litertlm` | `qwen3` | false |
| `deepseekR1` | DeepSeek R1 1.5B ⭐ | 1.7 GB | `.task` | `deepSeek` | true |
| `gemma4E2b` | Gemma 4 E2B | 2.4 GB | `.litertlm` | `gemma4` | false |
| `gemma4E4b` | Gemma 4 E4B | 4.3 GB | `.litertlm` | `gemma4` | false |

> The `AIModelId` enum value `qwen25_05b` is legacy — kept to avoid an enum-rename migration in users' SharedPreferences. The actual file and label are Qwen3 0.6B.

---

## Out of Scope

| Feature | Status | Why |
|---|---|---|
| Direct provider keys (Anthropic, OpenAI native) | Future | OpenRouter covers them all with one key; we'd add `llm_dart` as a second remote data source if/when requested. |
| Image / vision input on cloud | Future | OpenRouter supports it; UI not wired. |
| Function calling / tool use | Future | Gemma 4 + Qwen3 + most OpenRouter models support it. |
| Cost / usage display in chat | Future | OpenRouter returns usage per response. |
| Persistent on-device chat sessions | Future | Today we open a fresh `openChat` per turn for clean history. Long-lived sessions would save the per-turn prefill cost (84s on slow devices) but complicate branch switching. Phase 2 of v2 enabled it structurally; not yet enabled in code. |
| Hybrid keyword + vector search (BM25) | Future | Vector only today via ToStore. |
| Re-ranking with cross-encoder | Future | Top-K cosine only today. |
| Chunking of large notes | Future | One note = one embedding today. |
| NIP-09 deletion of conversations | Never | Same Feed-Freedom principle as notes. |
