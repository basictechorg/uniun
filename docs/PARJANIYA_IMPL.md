# What Parjaniya Built — Gateway + Channels + DMs

Simple explanation of what exists, how it connects, and what still needs to be built.

---

## Part 1 — The Gateway (Relay Sync Engine)

### The Big Idea

The app has **two Dart isolates** running at the same time:

```
Isolate 1 — Flutter UI
  reads and writes Isar normally

Isolate 2 — Gateway (Parjaniya's code)
  also has Isar open on the same file
  manages all WebSocket connections to relays
```

They never talk to each other directly. **Isar is the shared inbox/outbox between them.**

When the UI wants to send a note → it writes a row to `EventQueueModel` in Isar.  
The Gateway is watching Isar → it sees the new row → it sends it to the relay.  
When the relay sends a note back → Gateway writes it to `NoteModel` in Isar.  
Isar fires a watcher in the UI isolate → the feed updates automatically.

No `SendPort`. No `ReceivePort`. No polling. Just Isar watchers.

---

### Files

```
lib/gateway/
  gateway.dart                — app startup, spawns the isolate
  gateway_init_message.dart   — carries the Isar folder path into the isolate
  central_relay_manager.dart  — the orchestrator (one per app lifetime)
  websocket_service.dart      — one WebSocket connection per relay
```

---

### gateway.dart — How It Starts

```dart
// Called once at app launch (main.dart)
GatewayBootstrap.start()
  → Isolate.spawn(gatewayEntryPoint, GatewayInitMessage(isarDirectory: dir.path))
```

Inside the isolate:
1. Opens Isar at the same path as the UI isolate
2. Creates `CentralRelayManager(isar: isar)`
3. Calls `manager.start()`
4. The isolate stays alive forever (it holds active timers and stream subscriptions)

---

### central_relay_manager.dart — The Orchestrator

Think of this as the "boss" that manages all relay connections.

**On startup it does 4 things:**

1. **Reads all relays from `RelayModel`** (Isar). Creates one `WebSocketService` per relay. If no relays exist, it saves the default relay first.

2. **Watches `EventQueueModel`** — when the UI writes a new event to send, the watcher fires and tells all `WebSocketService`s to check the queue immediately (don't wait for next timer).

3. **Watches `RelayModel`** — when the UI adds or removes a relay at runtime, this watcher fires and syncs the services map (adds a new `WebSocketService` or removes the old one).

4. **Watches `FollowedNoteModel`** — when the user follows or unfollows a note, this watcher fires and tells each service to refresh its `#e` subscription filter.

**Every 5 minutes (cleanup timer):** deletes `EventQueueModel` rows that are older than 30 minutes (they've been sent already).

**Channel-specific relays (temporary services):**  
When a channel event (Kind 40–44) is queued, the manager checks `ChannelModel.relays` to see if this event needs to go to a specific relay URL beyond the main relays. If yes, it creates a temporary `WebSocketService` for that URL with a 5-minute auto-destroy timer.

---

### websocket_service.dart — One Connection Per Relay

Each `WebSocketService` manages one WebSocket URL. It handles both sending and receiving.

**Connection:**
- Connects on creation. If it fails or drops, reconnects with exponential backoff (1s, 2s, 4s, 8s... up to 60s max).

**On connect it immediately sends subscriptions:**

```
REQ feed_notes          → {"kinds": [1]}
                           "give me all Kind 1 notes"

REQ followed_note_refs  → {"kinds": [1], "#e": ["noteId1", "noteId2", ...]}
                           "give me notes that e-tag any of my followed notes"

REQ dms                 → {"kinds": [1059], "#p": [myPubkey]}
                           "give me gift-wrapped DMs addressed to me"

REQ profiles            → {"kinds": [0], "authors": [...missingPubkeys]}
                           "give me profiles for pubkeys we've seen but don't have yet"
```

**Sending (outbound queue):**
- Reads `EventQueueModel` rows where `id > _lastSentQueueId` (cursor-based).
- Sends one event at a time. Waits for `["OK", eventId, true]` from the relay before sending the next one.
- If the relay says OK → increments `sentCount` on the row, advances the cursor.
- If the relay rejects → still advances (don't retry forever).
- Channel events check `resolveTargets` — if this relay isn't the right one for this event, skips it.

**Receiving (inbound) — now handles 3 kinds:**

| Kind | Handler | What it does |
|------|---------|-------------|
| 1 | `_handleIncomingKind1Event` | Parses note → writes `NoteModel` (idempotent, skips duplicate eventId). Increments `cachedReplyCount` on parent/referenced notes. Bumps `FollowedNoteModel.newReferenceCount` if e-tags match a followed note. |
| 0 | `_storeIncomingKind0Profile` | Parses profile JSON → writes `ProfileModel`. Removes pubkey from `MissingProfilePubkeyModel` so we stop requesting it. |
| 1059 | `_storeEncryptedDm` | Stores raw gift-wrap event to `EncryptedDmModel` (undecrypted). UI layer decrypts on read via NIP-17 service. |

**Missing profile tracking:**
Every incoming event's `pubkey` + `p` tags are checked against `ProfileModel`. Any pubkeys not in Isar are written to `MissingProfilePubkeyModel`. A watcher on this table fires `_subscribeKind0Profiles()` to fetch the missing profiles from the relay automatically.

**NIP-10 parsing (done inside WebSocketService):**
```
["e", id, relay, "root"]    → NoteModel.rootEventId = id
["e", id, relay, "reply"]   → NoteModel.replyToEventId = id
["e", id, relay, "mention"] → NoteModel.eTagRefs += id
["p", pubkey, ...]           → NoteModel.pTagRefs += pubkey
["t", hashtag]               → NoteModel.tTags += hashtag
```

---

### What the Gateway Does NOT Do Yet

- Does **not** subscribe to channel messages (Kind 41/42). `SubscriptionRecordModel` exists in Isar but the Gateway doesn't read it yet to open live `REQ` filters for channels.
- Does **not** handle incoming Kind 42 (channel messages) — only stores the raw gift-wrap for DMs.

---

## Part 2 — Channels (NIP-28)

### Data Models (Isar)

**`ChannelModel`** — stores one channel per row:
```
channelId         — the Kind 40 event id (this IS the channel forever)
creatorPubKey     — who made it
name, about, picture — channel info (can be updated by Kind 41)
relays            — list of relay URLs this channel lives on
createdAt         — when Kind 40 was created
updatedAt         — timestamp of last accepted Kind 41 (metadata update)
lastMetaEvent     — event id of last accepted Kind 41
lastReadEventId   — unread tracking checkpoint (same pattern as Vishnu feed)
lastReadAt        — unix timestamp of last read
```

**`ChannelMessageModel`** — stores one Kind 42 message per row:
```
eventId        — the message's Nostr event id
channelId      — which channel it belongs to (Kind 40 event id)
authorPubkey   — who sent it
content        — the message text
eTagRefs       — e-tag references
rootEventId    — the channelId (Kind 40 id is the "root" for Kind 42)
replyToEventId — if this message replies to another message in the channel
created        — timestamp
```

**`SubscriptionRecordModel`** — stores what channels the user is subscribed to:
```
channelId       — which channel
kinds           — [41, 42, 43, 44]
eTags           — [channelId]
lastUntilByRelay — Map<relayUrl, unixTimestamp> (pagination cursor per relay)
enabled         — true/false
```

---

### Channel Use Cases (all done)

| Use Case | What It Does |
|----------|-------------|
| `CreateChannelUseCase` | Builds + signs Kind 40 → saves `ChannelModel` → enqueues in `EventQueueModel` → saves `SubscriptionRecordEntity` |
| `CreateChannelMessageUseCase` | Builds + signs Kind 42 → saves to `ChannelMessageModel` → enqueues in `EventQueueModel` |
| `SubscribeChannelUseCase` | Saves a `SubscriptionRecordEntity` for an existing channel |
| `GetChannelsUseCase` | Returns all channels from Isar |
| `GetChannelByIdUseCase` | Returns one channel by channelId |
| `GetChannelMessagesUseCase` | Returns paginated Kind 42 messages for a channel |

---

### Channel UI (Done)

| File | What It Is |
|------|-----------|
| `channels/create/pages/create_channel_page.dart` | Create channel form (name, about, picture, relay picker) |
| `channels/feed/pages/channel_feed_page.dart` | Channel message feed — scrollable Kind 42 list |
| `channels/feed/widgets/channel_message_composer.dart` | Send message input bar |
| `channels/feed/widgets/channel_reference_picker.dart` | Pick a note to reference in a channel message |
| `channels/thread/pages/channel_thread_page.dart` | Thread view for a channel message and its replies |

**`ChannelFeedBloc`** handles: load messages, send message, save/unsave a message, load profiles.

---

## Part 3 — DMs (NIP-17)

### How NIP-17 Works

Three-layer encryption:
```
Kind 14 (rumor — the actual message, UNSIGNED)
  → NIP-44 encrypt with sender privkey + recipient pubkey
  → Kind 13 (seal, signed by sender)
  → NIP-44 encrypt with ephemeral privkey + recipient pubkey
  → Kind 1059 (gift wrap, published to relay)
```

Only `["p", recipient_pubkey]` is visible on the relay. The relay cannot read content or know the sender.

### What's Built

**Encryption service:** `lib/domain/services/nip17_encryption_service.dart`
- `encryptMessage(content, senderPrivkey, recipientPubkey)` → produces signed Kind 1059 event
- `decryptMessage(kind1059Event, recipientPrivkey)` → unwraps gift wrap → decrypts seal → returns Kind 14 rumor content

**Data models:**
- `EncryptedDmModel` — stores raw Kind 1059 gift-wrap in Isar (undecrypted, as received by Gateway)
- `DmConversationModel` — one row per conversation (identified by other party's pubkey)
- `DmMessageModel` — one row per decrypted message

**Domain:**
- `DmConversationEntity`, `DmMessageEntity` (freezed)
- `DmConversationRepository`, `DmMessageRepository` (interfaces + impls)

**Use cases (`dm_usecases.dart`):**

| Use Case | What It Does |
|----------|-------------|
| `CreateDmConversationUseCase` | Creates a new `DmConversationModel` row for a new chat |
| `SendDmUseCase` | Encrypts message → produces Kind 1059 → enqueues in `EventQueueModel` → saves `DmMessageModel` locally |
| `GetDmUseCase` | Fetches all `EncryptedDmModel` rows, decrypts each, saves decrypted messages to `DmMessageModel` |
| `FetchDmUseCase` | Returns paginated `DmMessageEntity` list for a conversation |

**UI:**

| File | What It Is |
|------|-----------|
| `dm/create/pages/create_dm_page.dart` | Start a new DM — search for a user by pubkey/npub |
| `dm/chat/pages/dm_chat_page.dart` | DM chat view — scrollable message list + send bar |

**`DmChatBloc`** handles: load messages, send message, streaming updates.  
**`CreateDmBloc`** handles: pubkey input, resolve profile, create conversation.

---

## Summary: What's Done vs What's Left

```
✅  Gateway isolate bootstrap
✅  CentralRelayManager — Isar watcher orchestration
✅  WebSocketService — connect, send queue, receive Kind 1 + Kind 0 + Kind 1059
✅  Missing profile auto-fetch (MissingProfilePubkeyModel watcher)
✅  cachedReplyCount increment on incoming Kind 1 replies
✅  Followed note reference count bump
✅  ChannelModel + ChannelMessageModel + SubscriptionRecordModel
✅  All channel use cases
✅  Create channel page
✅  Channel feed page (message list + composer)
✅  Channel thread page
✅  NIP-17 encryption service (encrypt + decrypt)
✅  EncryptedDmModel + DmConversationModel + DmMessageModel
✅  All DM use cases (create conversation, send, fetch, decrypt)
✅  Create DM page
✅  DM chat page

🔲  Gateway: read SubscriptionRecordModel and open Kind 41/42 REQ per channel
🔲  Gateway: handle incoming Kind 42 → ChannelMessageModel
🔲  Channel list in drawer
🔲  Channel unread badge
🔲  Kind 41 metadata update UI
🔲  Subscribe to existing channel by ID (discovery flow)
```
