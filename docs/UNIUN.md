# UNIUN – Application Specification

## Overview

UNIUN is an **offline-first decentralized social + knowledge application** built on Nostr.

The app is centred around **Notes**, which act as:

* posts (like a social feed)
* messages (chat)
* knowledge units (graph-based, AI-searchable)

All data is stored locally in Isar and synced via Nostr relays. No custom backend for app logic — only a standard Nostr relay (`uniun-backend/`, Khatru + BadgerDB).

---

## Core Concepts

### Notes

Notes are the fundamental unit. **Every user-visible message — feed post, public channel message, DM, private channel message — is stored in the unified `Note` Isar collection, discriminated by the Nostr `kind` field**:

| `kind` | Surface | Container field |
|--------|---------|-----------------|
| 1      | Vishnu feed note          | — |
| 42     | Public channel (NIP-28)   | `channelId` |
| 14 / 15| Direct message (NIP-17)   | `conversationId` |
| 9023   | Private channel (NIP-29)  | `groupId` |

A note can contain:
* text
* image (URL via Blossom upload, NIP-92 `imeta` tag)
* user mentions (`p` tags)
* references to other notes (`e` tags — graph edges)
* topic tags (`t` tags — graph nodes)
* an embedded snapshot of another note (`embeddedNoteJson` — used by the Share sheet)

Notes are stored locally in Isar and published to Nostr relays via the Gateway isolate.

---

### Graph-Based References

Every `e` tag is a directed edge in a knowledge graph. Every `t` tag is a topic node. This structure is the foundation of the knowledge graph and GraphRAG — no separate construction needed, it emerges from the Nostr event graph naturally.

A note can:
* reply to one note (NIP-10 `reply` marker → stored as `replyToEventId`)
* reference multiple notes (`mention` markers → stored in `eTagRefs`)
* root of a thread (`root` marker → stored as `rootEventId`)

Note roles are **derived** from these fields — there is no `isReply` or `noteRole` column.

---

### Vishnu (Feed + Notes)

The main chronological feed of Kind 1 notes (top-level only — `rootEventId == null`).

Features:
* chronological feed, scoped to `[selfPubkey, ...followedPubkeys]` (NIP-02 contact list)
* note threads (BFS reply loading)
* save/unsave notes (for AI context and bookmarking)
* follow a note's reference graph (get notified when other notes cite it)
* unread tracking via `lastReadEventId` scroll-position checkpoint (`FeedReadStateModel`)
* NoteCard renders hashtag chips from `t` tags, embed cards from `embeddedNoteJson`, and media attachments from `imeta`

---

### Brahma (Create Note)

Note composition and publishing.

User can:
* write text
* attach image (Blossom upload → NIP-92 `imeta` tag, content-addressed by SHA-256)
* tag users (`p` tag)
* reference existing notes (`e` tag with `mention` marker)
* preview note reference graph before publishing
* save as draft (NIP-37 Kind 31234, local-only by default)

Signs note with user's private key. Broadcasts via the EventQueue → Gateway → relay.

#### Manas (named subsets of notes)

A **Manas** is a user-curated, named collection of notes (saved + own + drafts) — a focused knowledge base. Used as the context scope for Shiv (chat / Gana / Manthan / Composer-chat) instead of "all notes."

---

### Shiv (AI Assistant)

Fully on-device AI assistant with **GraphRAG** over the user's notes. No data leaves the device by default.

**LLM backend abstraction (`LlmRepository`):**
The app supports two backends behind a single contract:
* **Local (`flutter_gemma ^1.1.0`)** — default. User picks from: Qwen3 0.6B, DeepSeek R1, Gemma 4 E2B, Gemma 4 E4B. Selection persisted via `AppSettingsModel`.
* **Remote (OpenRouter)** — opt-in. API key stored in `FlutterSecureStorage` (Android Keystore / iOS Keychain), never in Isar.

Every consumer (Shiv chat, Manthan, Composer-chat, knowledge extraction) goes through `LlmRepository.sendChat` / `generateOneShot`. Dispatch is by active `LlmBackendType`.

**GraphRAG pipeline (`lib/features/shiv/rag/`):**

*Per turn (stateless — runner holds NO per-conversation state):*

1. **Embed query** via on-device embedder (`flutter_gemma_embeddings`, LiteRT all-MiniLM).
2. **Vector search** — cosine top-K, scoped to the picked Manas (`ManasContextLoader.merge`) or the whole library if no Manas selected.
3. **1-hop graph expansion** via `GetGraphNeighboursUseCase`.
4. **Memory lookup** — `MemoryNodeModel` wiki summaries for the expanded node set.
5. **`EnrichedContext`** bundled and laid out by `PromptBuilder` under a per-model `PromptBudget`.
6. **Persona anchor + answer cue** — for small models (Qwen3 0.6B), the prompt restates `"You are Shiv (NOT $userName). Reply as Shiv."` near the question and ends with `\n\nShiv:` to lock identity.
7. **Stream tokens** via `AIModelRunner` (`local_llm_runner.dart`) — opens a throwaway `openChat` per turn, re-feeds system + trimmed history + RAG.

**Conversation management:**
* Each chat is a `ShivConversationModel` persisted in Isar forever.
* Messages form a linked list via `parentId` — supports conversation branch tree view.
* Auto-title: first 40 chars of first user message.
* History drawer (Scaffold.drawer). Swipe to delete.
* Branch tree: visual force-directed graph of message nodes; tap to switch or fork from any node.

**Thinking tag handling (DeepSeek R1):**
* Model emits `<think>...</think>` before the answer.
* `ShivMessageBubble._parseThinking()` splits into collapsible thinking + visible response.
* Streaming bubble runs through `LlmTextSanitizer.clean()` to strip mojibake, tool-call envelopes, and stale `<think>` fragments before display.

#### Gana (autonomous AI agents)

Gana = user-defined AI worker that watches an input surface (channel / DM / user / followed note / standalone), runs over one-or-more Manases, and autonomously publishes the result.

* **Foreground engine** (`GanaEngine`) — long-lived isolate, reacts to Isar `watchLazy()`.
* **Background engine** (`gana_workmanager.dart`) — WorkManager (Android) / BGTaskScheduler (iOS) one-shot tick, own Isar, own direct `FlutterGemma` (no DI).
* Both delegate input→prompt assembly to `generation/gana_run.dart`.
* Trigger presets (`GanaTriggerPreset`) — single UI radio: once-on-enable / once-on-first-message / every-message / on-schedule / message-or-schedule.

#### Manthan (idea generator)

Swipe-deck feature that synthesizes 2–3 of the user's own notes into one new note, reusing the Shiv generation substrate. Cards are a local cache (not Nostr events).

#### Composer-chat (inline AI)

The shared `UniunComposer` doubles as an inline AI chat — tap the avatar in any surface (thread / channel / DM / private), pick a Manas, ask. Streams the answer grounded in that surface's recent messages + the Manas. Works everywhere the composer renders.

---

### Public Channels (NIP-28)

Group chat that anyone can discover and join.

* Kind 40 = channel creation. The Kind 40 event ID **is** the channel ID forever.
* Kind 41 = channel metadata update (creator only).
* Kind 42 = channel message.
* Join by: scanning QR code (`UniunChannelQrCard` → `QrScannerPage`) or entering channel ID manually (`JoinChannelPage`).
* Channel feed (`ChannelFeedPage`): message list, composer (with composer-chat), thread navigation, QR share.
* Unread tracking via `lastReadEventId` (`ChannelReadStateModel`).

---

### Private Channels (NIP-29 E2EE)

Encrypted group chat using **MLS (Messaging Layer Security)** via the `openmls` Dart package, transported over Nostr Kind 9023 events with the `h` tag for group routing. The relay sees only encrypted payloads.

* Create: `CreatePrivateChannelPage` → `MarmotTransportService.createChannel()`.
* Join: `JoinPrivateChannelPage` — user enters group ID shared by admin.
* Chat: `PrivateChannelDetailPage` — message list, send, admin join-request management.
* Admin sees pending join requests with badge count in AppBar.
* Invite mechanism: admin shares group ID (Copy Group ID) or QR code.
* MLS state persisted in `mls_data.db` (SQLCipher encrypted) via `MarmotMlsService`.
* Messages stored in the unified `Note` collection (`kind == 9023`, `groupId` set).

---

### Direct Messages (NIP-17)

Encrypted 1:1 messaging with full 3-layer wrapping.

* **Kind 14** = the rumor (unsigned, plaintext message content).
* **Kind 13** = seal (NIP-44 encrypted Kind 14, signed by sender).
* **Kind 1059** = gift wrap (NIP-44 encrypted Kind 13 with ephemeral key, only `["p", recipient]` visible).
* Inbound subscription: `{"kinds":[1059], "#p":["myPubkey"]}`.
* Inbound flow: gift wrap → `EncryptedDmModel` queue → `Nip17EncryptionService` decrypts → writes decrypted Kind 14 into the unified `Note` collection.
* UI: `DmChatPage` + `CreateDmPage`.
* Unread tracking via `DMReadStateModel`.

---

### Content Moderation (NIP-56)

Users can report any foreign note or user for one of seven categories: `nudity / malware / profanity / illegal / spam / impersonation / other`.

* Three-dot menu on any foreign note → **Report note** → modal bottom sheet (`ReportSheetPage`) → pick a category + optional 280-char reason + optional "Also block this user" checkbox → Submit.
* Three effects on Submit:
  1. A signed **Kind 1984** event is enqueued for relay broadcast and a local `ReportModel` row is persisted.
  2. The reported note is **hidden locally** (tombstoned via the existing delete-note system) so it stops appearing in this user's feed / threads.
  3. If "Also block this user" was ticked, the author is added to the local `BlockedUserModel` list — every future event from that pubkey is dropped at the gateway.
* Settings → **My Reports** lists every report this identity has filed.
* `e`/`p` tags carry the report type as their final positional entry: `["e", target_id, "", "spam"]` / `["p", target_pubkey, "spam"]`.
* UNIUN does **not** consume reports authored by others in v1 — aggregation / filtering is left to the relay (NIP-56 itself warns automod-off-reports is easily gamed).

Permanently excluded: NIP-09 (event deletion) — see the No Delete section.

### Saved Notes

* Stored locally in Isar (`SavedNoteModel` — separate from the `Note` collection; it's a forever-retained bookmark copy).
* Not synced to relay — private bookmarks only.
* Primary purpose: RAG context for Shiv AI and Manas membership.

---

### Followed Notes

Subscribing to a note's reference graph — distinct from saved notes and from followed users.

* `FollowedNoteModel` stores `eventId`, `contentPreview`, `followedAt`, `newReferenceCount`.
* Gateway opens `{"kinds":[1], "#e":["followedNoteId"]}` per followed note.
* `newReferenceCount` incremented on each new match; shown as unread badge in drawer.
* Tapping in drawer → `FollowedNoteDetailPage` (original note + incoming references).

### Followed Users (NIP-02 / Kind 3)

* `FollowedUserModel` is the local mirror of the user's Kind 3 contact list.
* The Vishnu feed `authors` filter scopes to `[selfPubkey, ...followedPubkeys]` — empty follow list ⇒ feed shrinks to own notes only.
* When the follow set changes, the feed subscription is re-opened automatically.

---

### Share Sheet (embed-by-value)

The share button on any NoteCard opens `ShareSheetPage` with destinations: Feed / Public channel / Private channel / DM, plus "Share via…" external link via `share_plus`.

* The shared original is carried **by value** as an `embeddedNoteJson` tag — a self-contained JSON snapshot of `{id, pubkey, created_at, kind, tags, content, sig}` of the original event.
* Receiver renders the embed with **no Isar lookup, immune to retention**.
* Signature verified once at inbound; on failure the embed shows an "unverified" badge.
* External URL: `https://www.uniun.in/note/<hex>` (App Links + Universal Links).

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

Gana background tick (Isolate 3 — WorkManager / BGTaskScheduler)
  ↕ own Isar handle, direct flutter_gemma (no DI)
```

* The **Gateway isolate** is the only component that talks to relays. Flutter UI never touches relays directly — Isar is the bus between isolates.
* The **foreground Gana engine** runs in the main isolate. When the app is backgrounded, scheduled Gana ticks run via WorkManager (Android) / BGTaskScheduler (iOS) in their own short-lived isolate.

### Clean Architecture layers

```
Flutter UI (BLoC / Cubit)
    ↓ calls use cases
Domain (entities, repository interfaces, use cases)
    ↑ implemented by
Data (Isar models, repository impls)
```

Strict unidirectional dependency flow. Domain has zero Flutter / Isar imports.

---

## Nostr Protocol Usage

| NIP | Purpose |
|-----|---------|
| NIP-01 | Base event format and relay protocol |
| NIP-02 | Contact list (Kind 3) — drives feed scope |
| NIP-05 | Human-readable identifiers in profiles |
| NIP-10 | Note threading (`root`/`reply`/`mention` e-tag markers) |
| NIP-17 | Direct messages (Kind 14 rumor / 13 seal / 1059 gift wrap) |
| NIP-28 | Public channels (Kind 40 / 41 / 42) |
| NIP-29 | Private channels (Kind 9023 family, `h` tag routing, MLS payload) |
| NIP-37 | Drafts (Kind 31234, `d` / `expiration` tags) |
| NIP-44 | Encryption for DM and private-channel payloads (ChaCha20-Poly1305) |
| NIP-77 | Negentropy set reconciliation (efficient relay sync) |
| NIP-56 | Content reporting (Kind 1984 with `e`/`p` tags carrying a report type) |
| NIP-92 | Inline media metadata (`imeta` tag) |
| BUD-01/03 | Blossom media upload + user server list (Kind 10063 / 24242) |

Permanently excluded: **NIP-09 (deletion)**, NIP-04 (legacy DM encryption).

---

## Event Kinds Used

| Kind | Meaning |
|------|---------|
| 0 | User profile |
| 1 | Public note (feed, threads, knowledge graph) |
| 3 | Contact list (NIP-02 follow list) |
| 6 | Repost |
| 7 | Reaction |
| 13 | DM seal (NIP-17 layer 2) |
| 14 | DM rumor (NIP-17 content) |
| 40 | Public channel creation |
| 41 | Public channel metadata update |
| 42 | Public channel message |
| 1059 | DM gift wrap (NIP-17 outer envelope) |
| 1984 | Content report (NIP-56) — carries `e`/`p` tags with a report type |
| 9023 | Private channel encrypted message (NIP-29 family 9002–9025) |
| 10063 | User's Blossom server list |
| 24242 | Blossom auth token |
| 31234 | Note draft (NIP-37) |

---

## On-device AI Stack

| Component | Purpose |
|-----------|---------|
| `flutter_gemma ^1.1.0` | Local LLM runner (Qwen3 0.6B / DeepSeek R1 / Gemma 4 E2B/E4B) |
| `flutter_gemma_litertlm` | `.litertlm` engine (Qwen3, Gemma 4) |
| `flutter_gemma_mediapipe` | `.task` engine (DeepSeek R1) |
| `flutter_gemma_embeddings` | LiteRT embedder for RAG vector search |
| `tostore ^3.1.0` | On-device vector DB for embeddings |
| `openrouter_api ^1.0.2` | Optional cloud LLM backend (opt-in, key in secure storage) |
| `openmls` | MLS group encryption for private channels |
| GPU delegate (Android) / Metal (iOS) | LLM acceleration with CPU fallback |

---

## What Is Built vs Pending

| Feature | Status |
|---------|--------|
| Onboarding (welcome, key gen, import, profile setup) | ✅ Done |
| Home shell + floating nav (Vishnu / Brahma / Shiv) | ✅ Done |
| Vishnu feed — BLoC, NoteCard, pagination, save/unsave | ✅ Done |
| Thread view — BFS load, nested replies, reply composer | ✅ Done |
| Followed notes — cubit, detail page, reference graph | ✅ Done |
| Followed users (NIP-02 Kind 3) — feed scoping | ✅ Done |
| Settings — profile edit, identity, storage, style, AI | ✅ Done |
| Brahma create note — compose, graph preview, Blossom image | ✅ Done |
| Drafts (NIP-37) | ✅ Done |
| Manas (named subsets) | ✅ Done |
| Shiv AI — GraphRAG, graph expand, memory nodes, branch tree, streaming | ✅ Done |
| LLM backend abstraction (local flutter_gemma + remote OpenRouter) | ✅ Done |
| Gana (autonomous agents, foreground + WorkManager background) | ✅ Done |
| Manthan (swipe-deck idea generator) | ✅ Done |
| Composer-chat (inline AI in every composer) | ✅ Done |
| Public channels — create, feed, thread, join by QR/ID | ✅ Done |
| Private channels (NIP-29) — create, join, chat, admin join-requests, MLS E2EE | ✅ Done |
| DMs (NIP-17) — Kind 14 / 13 / 1059 full 3-layer encryption + UI | ✅ Done |
| Share sheet — embed-by-value (`embeddedNoteJson`), all destinations | ✅ Done |
| Content moderation — NIP-56 reporting + My Reports + Settings entry | ✅ Done |
| QR system (user / channel / private channel) | ✅ Done |
| Deep links (App Links + Universal Links — `www.uniun.in`) | ✅ Done |
| Blossom media upload + cache | ✅ Done |
| Web build (LiteRT has limited web support — needs evaluation) | 🔲 Pending |

---

## Goal

UNIUN provides a **decentralized, offline-first social + knowledge system** combining:

* social feed (Vishnu)
* note creation + knowledge graph (Brahma)
* curated knowledge bases (Manas)
* E2EE group messaging (Private Channels, NIP-29 + MLS)
* E2EE direct messaging (DMs, NIP-17)
* on-device GraphRAG AI assistant (Shiv)
* autonomous AI agents (Gana)
* AI-assisted idea synthesis (Manthan)
* inline AI co-pilot in every composer (Composer-chat)

All controlled by the user. No central servers. No cloud AI by default.
