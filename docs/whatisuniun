# UNIUN – Application Specification

## Overview

UNIUN is an **offline-first decentralized social + knowledge application** built on Nostr.

The app is centred around **Notes**, which act as:

* posts (like a social feed)
* messages (chat)
* knowledge units (graph-based, AI-searchable)

All data is stored locally in Isar and synced via Nostr relays. No custom backend for app logic — only a standard Nostr relay.

---

## Core Concepts

### Notes

Notes are the fundamental unit. A note can contain:

* text
* image (URL via Blossom upload)
* user mentions (`p` tags)
* references to other notes (`e` tags — graph edges)
* topic tags (`t` tags — graph nodes)

Notes are stored locally in Isar and published to Nostr relays via the Gateway isolate.

---

### Graph-Based References

Every `e` tag in a note is a directed edge in a knowledge graph. Every `t` tag is a topic node. This structure is the foundation of the knowledge graph and GraphRAG — no separate construction needed, it emerges from the Nostr event graph naturally.

A note can:
* reply to one note (NIP-10 `reply` marker)
* reference multiple notes (`mention` markers)

This creates threads, idea links, and a personal knowledge graph simultaneously.

---

### Vishnu (Feed + Notes)

The main chronological feed of Kind 1 notes.

Features:
* chronological feed (top-level notes only — `rootEventId == null`)
* note threads (BFS reply loading)
* save/unsave notes (for AI context and bookmarking)
* follow a note's reference graph (get notified when other notes cite it)
* NoteCard renders hashtag chips from `t` tags

---

### Brahma (Create Note)

Note composition and publishing.

User can:
* write text
* attach image (Blossom upload → `imeta` tag)
* tag users (`p` tag)
* reference existing notes (`e` tag with `mention` marker)
* preview note reference graph before publishing

Signs note with user's private key. Broadcasts via the EventQueue → Gateway → relay.

---

### Shiv (AI Assistant)

Fully on-device AI assistant with **GraphRAG** over the user's saved notes. No cloud API. No data leaves the device.

**Model selection:**
User picks from: Qwen3 0.6B, DeepSeek R1, Gemma 4 E2B, Gemma 4 E4B. Selection persisted in Isar (`AppSettingsModel`). If no model is active, Shiv redirects to the selection screen.

**Two-phase RAG pipeline (GraphRAG):**

Phase 1 — session open (once per conversation):
1. `EmbeddingService.init()` — loads all-MiniLM-L6-v2 (TFLite, ~80 MB) from device storage.
2. `RagPipeline.buildSystemInstruction()` — loads user profile + own notes → builds Shiv persona + user context as a static system instruction string.
3. `AIModelRunner.initChat(systemInstruction:)` — opens `InferenceChat` via `flutter_gemma ^0.13.2`.

Phase 2 — each user message:
1. Embed query → cosine similarity search → top-K seed notes (`VectorSearchService`).
2. Pull `MemoryNodeEntity` wiki summaries for seed note IDs → extract concept keys.
3. 1-hop graph expansion via concept keys → `GraphEdgeEntity` list (`GetGraphNeighboursUseCase`).
4. `GetGraphNodesByKeysUseCase` → node labels for edge endpoints.
5. Pull memories for notes referenced in the expanded graph edges.
6. Bundle into `EnrichedContext(seedNotes, graphNodes, graphEdges, memories)`.
7. `PromptBuilder.buildUserMessage()` lays out context inside a per-model `PromptBudget` (dynamic token allocation by priority).
8. `AIModelRunner.sendAndStream()` streams tokens back.

`InferenceChat` manages conversation history internally — each turn only receives current question + RAG context, not the full history.

**Conversation management:**
* Each chat is a `ShivConversation` persisted in Isar forever.
* Messages form a linked list via `parentId` — supports conversation branch tree view.
* Auto-title: first 40 chars of first user message.
* History drawer (Scaffold.drawer). Swipe to delete a conversation.
* Branch tree: visual force-directed graph of message nodes; tap to switch branch or fork from any node.

**Thinking tag handling:**
* DeepSeek R1 emits `<think>...</think>` blocks before the actual response.
* `ShivMessageBubble._parseThinking()` splits into collapsible thinking section + visible response.
* This only applies inside Shiv — `NoteCard` in feed/channel does not strip these tags (known issue if AI-generated content with think tags is published as a note).

**Stack:** flutter_gemma 0.13.2 · tflite_flutter 0.12.0 · all-MiniLM-L6-v2 · Isar · Tostore (vector DB)

---

### Public Channels (NIP-28)

Group chat that anyone can discover and join.

* Kind 40 = channel creation. The Kind 40 event ID **is** the channel ID forever.
* Kind 41 = channel metadata update (creator only).
* Kind 42 = channel message.
* Join by: scanning QR code (`UniunChannelQrCard` → `QrScannerPage`) or entering channel ID manually (`JoinChannelPage`).
* QR payload: `{"k":40,"id":"<hex>","pk":"<hex>","ca":<ts>,"n":"<name>","a":"<about>"}`.
* Channel feed (`ChannelFeedPage`): message list, composer, thread navigation, QR share button.
* Unread tracking via `lastReadEventId` scroll-position checkpoint.

---

### Private Channels (E2EE Group Messaging)

Encrypted group chat using **MLS (Messaging Layer Security)** via the `openmls` Dart package, transported over Nostr Kind 42 events. The relay sees only encrypted payloads — it cannot read private channel messages.

* Create: `CreatePrivateChannelPage` + `CreatePrivateChannelUsecase` → `MarmotTransportService.createChannel()`.
* Join: `JoinPrivateChannelPage` + `JoinPrivateChannelBloc` — user enters group ID shared by admin.
* Chat: `PrivateChannelDetailPage` + `PrivateChannelDetailBloc` — message list, send, admin join-request management.
* Admin sees pending join requests with badge count in AppBar.
* Invite mechanism: admin shares group ID (Copy Group ID) or QR code.
* MLS state persisted in `mls_data.db` (SQLCipher encrypted) via `MarmotMlsService`.
* Transport layer (`MarmotTransportService`) wraps MLS operations into Nostr Kind 42 events.
* Isar models: `PrivateChannelModel`, `PrivateChannelMessageModel`, `PrivateChannelJoinRequestModel`.

---

### Direct Messages (DM)

Simple 1:1 messaging using Kind 14 (NIP-17 rumor format).

* Schema and Gateway wiring done.
* UI exists (`DmChatPage`, `CreateDmPage`) but is minimal.
* Full 3-layer encryption (Kind 14 → Kind 13 seal → Kind 1059 gift wrap) is a future item.

---

### Saved Notes

* Stored locally in Isar (`SavedNoteModel`).
* Not synced to relay — private bookmarks only.
* Primary purpose: RAG context for Shiv AI.

---

### Followed Notes

Subscribing to a note's reference graph — distinct from saved notes.

* `FollowedNoteModel` stores eventId, contentPreview, followedAt, newReferenceCount.
* Gateway opens `{"kinds":[1],"#e":["followedNoteId"]}` per followed note.
* `newReferenceCount` incremented on each new match; shown as unread badge in drawer.
* Tapping in drawer → `FollowedNoteDetailPage` (original note + incoming references).

---

### No Delete

Notes are permanent. No delete — not local, not relay. NIP-09 is intentionally excluded. Feed freedom is a core principle.

---

## Architecture

```
Flutter UI (Isolate 1)
  ↕ reads/writes Isar (shared on-disk file)
Gateway (Isolate 2 — CentralRelayManager + WebSocketService)
  ↕ WebSocket NIP-01 + NIP-77 (Negentropy sync)
Nostr Relay (uniun-backend — Khatru + BadgerDB)
```

The Gateway is a separate Dart isolate. It watches Isar for new queue entries (outbound) and writes incoming events to Isar (inbound). The Flutter UI only talks to Isar — never directly to the relay.

---

## Nostr Protocol Usage

| NIP | Purpose |
|-----|---------|
| NIP-01 | Base event format and relay protocol |
| NIP-10 | Note threading (`root`/`reply`/`mention` e-tag markers) |
| NIP-17 | Direct messages (Kind 14 rumor format) |
| NIP-28 | Public channels (Kind 40/41/42) and Private channel transport (Kind 42 with MLS payload) |
| NIP-44 | Encryption for DM payloads (ChaCha20-Poly1305) |
| NIP-05 | Human-readable identifiers in profiles |
| NIP-77 | Negentropy set reconciliation (efficient relay sync) |

Permanently excluded: NIP-09 (deletion), NIP-04 (legacy DM encryption).

---

## Event Kinds Used

| Kind | Meaning |
|------|---------|
| 0 | User profile |
| 1 | Public note (feed, threads, knowledge graph) |
| 7 | Reaction (like) |
| 14 | Direct message (NIP-17 rumor) |
| 40 | Public channel creation |
| 41 | Public channel metadata update |
| 42 | Public channel message / Private channel encrypted message |
| 10063 | User's Blossom server list |
| 24242 | Blossom auth token |

---

## What Is Built vs Pending

| Feature | Status |
|---------|--------|
| Onboarding (welcome, key gen, import, profile setup) | ✅ Done |
| Home shell + floating nav (Vishnu / Brahma / Shiv) | ✅ Done |
| Vishnu feed — BLoC, NoteCard, pagination, save/unsave | ✅ Done |
| Thread view — BFS load, nested replies, reply composer | ✅ Done |
| Followed notes — cubit, detail page, reference graph | ✅ Done |
| Settings — profile edit, identity, storage, style, AI | ✅ Done |
| Brahma create note — compose, graph preview, Blossom image | ✅ Done |
| Shiv AI — GraphRAG, graph expand, memory nodes, branch tree, streaming | ✅ Done |
| Public channels — create, feed, thread, join by QR/ID | ✅ Done |
| Private channels — create, join, chat, admin join-requests, MLS E2EE | ✅ Done |
| QR card system (UniunQrCard user / UniunChannelQrCard channel) | ✅ Done |
| DMs (NIP-17) full UI | 🔲 Pending |
| Web build (tflite_flutter has no web support — needs ONNX alternative) | 🔲 Pending |

---

## Goal

UNIUN provides a **decentralized, offline-first social + knowledge system** combining:

* social feed (Vishnu)
* note creation + knowledge graph (Brahma)
* E2EE group messaging (Private Channels)
* on-device GraphRAG AI (Shiv)

All controlled by the user. No central servers. No cloud AI.
