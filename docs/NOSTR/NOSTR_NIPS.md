# UNIUN — Nostr Protocol Reference & NIPs

## Everything Is an Event

The single most important thing to understand about Nostr:

> **There are no users, channels, notes, or messages as separate types. Everything is a `NostrEvent`. The `kind` field determines what it means.**

```
NostrEvent {
  id:         SHA256 of the canonical serialization
  pubkey:     author's secp256k1 public key (this IS the user identity)
  created_at: Unix timestamp
  kind:       integer — determines meaning
  tags:       [[tag_name, value, ...], ...]
  content:    string — meaning depends on kind
  sig:        Schnorr signature over id
}
```

A "user" = their `pubkey` + a `Kind 0` event with profile metadata.
A "channel" = a `Kind 40` event. Its `event_id` becomes the channel ID forever.
A "note" = a `Kind 1` event.
A "DM" = a `Kind 14` event wrapped inside `Kind 13` wrapped inside `Kind 1059`.

---

## Kind Reference (UNIUN-relevant)

| Kind | Name | What it is |
|---|---|---|
| 0 | User Metadata | User profile (name, avatar, nip05, about) |
| 1 | Short Text Note | A public note (tweet-like) |
| 5 | Deletion | Request to delete one or more events |
| 6 | Repost | Repost of a Kind 1 |
| 7 | Reaction | Like or emoji on any event |
| 13 | Seal | Layer 2 of encrypted DM |
| 14 | DM Chat Message | The actual DM content (inner rumor) |
| 40 | Channel Creation | Creates a public channel |
| 41 | Channel Metadata | Update channel name/description/icon |
| 42 | Channel Message | Message sent inside a channel |
| 43 | Hide Message | Client-side hide a channel message |
| 44 | Mute User | Client-side mute a user in channels |
| 1059 | Gift Wrap | Outer envelope for encrypted DMs |
| 10050 | DM Relay List | User's preferred DM relays |
| 10063 | User Server List | User's preferred Blossom servers |
| 24242 | Blossom Auth | Signed auth token for Blossom uploads |

---

## Tag Reference

Tags are the linking mechanism. They connect events to other events, users, and metadata.

```
["e", event_id, relay_url, marker, pubkey]  → references another event
["p", pubkey, relay_url]                    → references a user
["t", hashtag]                              → topic tag
["a", kind:pubkey:d-tag, relay_url]         → reference to replaceable event
["d", identifier]                           → unique id for replaceable events
["imeta", "url ...", "m ...", "x ..."]      → inline media metadata (NIP-92)
["subject", text]                           → DM thread subject
["expiration", timestamp]                   → event auto-expires after this
```

**e-tag markers** (NIP-10 threading):
- `"root"` — the top-level post of the thread
- `"reply"` — the direct parent being replied to
- `"mention"` — cited for reference only

---

## NIP-01 — Base Protocol

**How relays work:**

```
Client → Relay: ["REQ", "sub_id", {filter}]     ← subscribe
Relay → Client: ["EVENT", "sub_id", {event}]    ← events matching filter
Relay → Client: ["EOSE", "sub_id"]              ← end of stored events, live starts
Client → Relay: ["EVENT", {event}]              ← publish an event
Relay → Client: ["OK", "event_id", true, ""]    ← publish confirmed
Client → Relay: ["CLOSE", "sub_id"]             ← unsubscribe
```

**Filter structure:**
```json
{
  "kinds":   [1, 42],
  "authors": ["pubkey1", "pubkey2"],
  "#e":      ["event_id"],
  "#p":      ["pubkey"],
  "#t":      ["nostr"],
  "since":   1700000000,
  "until":   1700100000,
  "limit":   50
}
```

Multiple filters in one REQ are ORed together. Fields within a filter are ANDed.

---

## NIP-10 — Replies and Threading

How to build a thread of notes:

```dart
// Direct reply to a root note:
tags: [
  ["e", rootNoteId, relayUrl, "root", rootAuthorPubkey],
  ["p", rootAuthorPubkey]
]

// Reply to a reply (nested):
tags: [
  ["e", rootNoteId, relayUrl, "root", rootAuthorPubkey],
  ["e", parentNoteId, relayUrl, "reply", parentAuthorPubkey],
  ["p", rootAuthorPubkey],
  ["p", parentAuthorPubkey]
]
```

**Rule:** Always carry forward all `p` tags from the parent event, then add the parent's own pubkey. This ensures everyone in the thread gets notified.

---

## NIP-28 — Public Chat Channels

A channel lifecycle:

### Create Channel (Kind 40)
```json
{
  "kind": 40,
  "content": "{\"name\":\"Python Devs\",\"about\":\"Python programming\",\"picture\":\"https://...\"}",
  "tags": []
}
```
The `event.id` of this event **is** the channel ID forever.

### Update Channel (Kind 41) — creator only
```json
{
  "kind": 41,
  "content": "{\"name\":\"Updated Name\"}",
  "tags": [["e", "<kind40_event_id>", "relay_url", "root"]]
}
```

### Send Message (Kind 42)
```json
{
  "kind": 42,
  "content": "Hello channel!",
  "tags": [
    ["e", "<kind40_event_id>", "relay_url", "root"],
    ["e", "<parent_message_id>", "relay_url", "reply"],
    ["p", "<parent_message_author_pubkey>"]
  ]
}
```

### Query a channel's messages
```json
["REQ", "sub1", {"kinds": [42], "#e": ["<kind40_id>"], "limit": 50}]
```

---

## NIP-17 + NIP-44 — Private DMs

Three layers of encryption. The actual message never hits a relay unencrypted.

```
Kind 14 (rumor — actual DM, UNSIGNED)
  ↓ NIP-44 encrypt with sender privkey + recipient pubkey
Kind 13 (seal — signed, but tags EMPTY, timestamp randomized)
  ↓ NIP-44 encrypt with ephemeral privkey + recipient pubkey
Kind 1059 (gift wrap — published to relay, only ["p", recipient] tag visible)
```

**One gift wrap per recipient.** Group DMs = multiple gift wraps, one per member.

**NIP-44 encryption algorithm:**
- Key exchange: secp256k1 ECDH → shared x coordinate
- KDF: HKDF-SHA256 with salt `"nip44-v2"`
- Encryption: ChaCha20 stream cipher
- Auth: HMAC-SHA256
- Padding: power-of-two to hide message length

**Receive flow:**
1. Subscribe `{"kinds": [1059], "#p": ["my_pubkey"]}` on DM relays
2. Decrypt gift wrap → get seal
3. Verify seal signature
4. Decrypt seal → get rumor (Kind 14)
5. Verify rumor pubkey matches seal pubkey

---

## NIP-09 — Event Deletion

```json
{
  "kind": 5,
  "content": "Posted by mistake",
  "tags": [
    ["e", "<event_id_to_delete>"],
    ["k", "1"]
  ]
}
```

- Only works if deletion event `pubkey` matches the deleted event's `pubkey`
- Relay stops serving the deleted event but keeps the Kind 5 deletion event
- Clients must verify pubkey match before hiding

---

## NIP-05 — Human Readable Usernames

User sets in their Kind 0 content:
```json
{"name": "sam", "nip05": "sam@uniun.app"}
```

Client verifies by fetching:
```
GET https://uniun.app/.well-known/nostr.json?name=sam
```

Expected response:
```json
{
  "names": {
    "sam": "<hex_pubkey>"
  }
}
```

If the hex pubkey matches the Kind 0 event pubkey → verified. The domain IS the identity. `_@uniun.app` = root identifier, display as just `uniun.app`.

---

## Custom Solutions (App-Level, No NIP)

### Private Groups (Multi-person DMs)

There is no NIP for private group chats. UNIUN solution:

**Protocol layer:** Use NIP-17 DMs — send the same Kind 14 rumor, wrapped separately for each member (one Kind 1059 per member).

**App layer (Isar only):**
```
PrivateGroupModel (Isar)
  - groupId: String  ← app-generated UUID
  - name: String
  - creatorPubkey: String
  - memberPubkeys: List<String>
  - inviteToken: String  ← sha256 of (groupId + creatorPubkey)
  - created: DateTime

GroupMessageModel (Isar)
  - groupId: String
  - eventId: String  ← the Kind 14 event ID
  - senderPubkey: String
  - content: String  ← decrypted
  - created: DateTime
```

A message tagged with `["group", groupId]` in the Kind 14 rumor's tags allows the app to group conversations visually. Members who join receive the groupId + member list via the first DM.

---

### Public Channel Permission Levels

NIP-28 has no permission system. UNIUN solution — store at app level:

```
ChannelPermissionModel (Isar)
  - channelId: String      ← Kind 40 event ID
  - ownerPubkey: String    ← channel creator
  - moderators: List<String>
  - inviteOnly: bool
  - inviteTokens: List<ChannelInviteToken>

ChannelInviteToken (Isar)
  - token: String          ← sha256(channelId + inviterPubkey + nonce)
  - createdBy: String
  - usedBy: String?
  - expiresAt: DateTime?
  - maxUses: int
```

Enforcement is client-side. The app shows "invite required" UI for invite-only channels. Moderator actions (Kind 43 hide, Kind 44 mute) are stored locally and optionally broadcast so other members with the same moderation data see the same view.

---

## Relay Communication Protocol (UNIUN EmbeddedServer)

```
Mobile App
  └── EmbeddedServer (Dart Isolate)
        ├── RelayConnector
        │     ├── wss://relay1  (WebSocket)
        │     ├── wss://relay2  (WebSocket)
        │     └── wss://relay3  (WebSocket)
        ├── SyncEngine
        │     ├── processIncoming(NostrEvent) → write to Isar
        │     └── flushQueue() → send pending events to relay
        └── CleanupManager
              ├── retentionDays: 7 (configurable)
              ├── deleteOldNotes() → removes unsaved Kind 1 notes from Isar
              └── fetchOnDemand(eventId) → relay fetch when note not in Isar
```

**Relay filter subscriptions UNIUN opens:**
```dart
// Feed: all Kind 1 notes from followed pubkeys
{"kinds": [1], "authors": [...followedPubkeys], "limit": 50}

// Channel messages
{"kinds": [40, 41, 42], "#e": [channelId], "limit": 100}

// DMs for this user
{"kinds": [1059], "#p": [myPubkey]}

// Profile metadata
{"kinds": [0], "authors": [pubkey]}
```

---

## Isar Retention Policy (CleanupManager)

| Note Type | Isar Retention |
|---|---|
| Kind 1 (regular note, not saved) | Delete after 7 days (configurable) |
| Kind 1 (saved note, `saved = true`) | Keep forever |
| Kind 1 (own note, `authorPubkey = myPubkey`) | Keep forever |
| Kind 42 (channel message) | Delete after 3 days (configurable) |
| Kind 14 (DM content) | Keep forever (user's own messages) |
| Kind 0 (profiles) | Keep for 30 days, refresh on view |
| AI conversation / messages | Keep forever |

**On-demand fetch:** If Vishnu or Brahma needs a note not in Isar → `SyncEngine.fetchById(eventId)` → relay query `{"ids": [eventId]}` → write to Isar → return to UI.

---

## Blossom Media Management

**What is Blossom:** A content-addressed HTTP blob store for Nostr. Files are identified by their SHA-256 hash. Same file = same URL on any Blossom server.

**UNIUN upload flow:**
```
1. User selects image
2. App computes SHA-256 locally
3. HEAD /<sha256> on user's Blossom server → check if already uploaded
4. If not found:
   - Sign Kind 24242 auth event (t=upload, x=sha256, expiration=+10min)
   - PUT /upload with auth header + file bytes
   - Receive blob descriptor: {url, sha256, size, type}
5. Embed in Nostr event:
   content: "my photo https://cdn.example.com/<sha256>.jpg"
   tags: [["imeta", "url https://cdn.example.com/...", "m image/jpeg", "x <sha256>", "dim 1080x1080"]]
```

**User's Blossom server config:**
```
Kind 10063 event:
  tags: [
    ["server", "https://primary-blossom.example.com"],
    ["server", "https://backup-blossom.example.com"]
  ]
```

**Media Auth (Kind 24242):**
```json
{
  "kind": 24242,
  "tags": [
    ["t", "upload"],
    ["x", "<sha256>"],
    ["expiration", "<unix_ts + 600>"]
  ],
  "content": "Upload image"
}
```

**Fallback strategy:** If Blossom URL 404s → extract SHA-256 from URL → look up author's Kind 10063 → retry on their other servers.

---

## Build Order Recommendation

```
Phase 1 — Foundation (no UI yet)
  ├── NostrEvent model (Isar @collection)
  ├── EmbeddedServer + RelayConnector
  ├── SyncEngine (incoming events → Isar)
  ├── EventQueue (outgoing events with offline support)
  └── CleanupManager (retention policy)

Phase 2 — Vishnu (core feed)
  ├── Isar → NoteEntity domain projection
  ├── VishnuFeedBloc
  ├── NoteCard + NoteCardRenderer (Factory for kind 1 variants)
  └── Channel filter bar (local view from Kind 40 events)

Phase 3 — Brahma (create notes)
  ├── BrahmaCreateBloc
  ├── Editor + image attach (Blossom upload)
  ├── Reference picker + graph preview
  └── Submit → EventQueue → relay

Phase 4 — Drawer + Channels
  ├── DrawerBloc
  ├── Channel list (Kind 40 events from Isar)
  └── DM list (Kind 1059 decrypted, grouped)

Phase 5 — Shiv (AI)
  ├── Embedding model setup (nomic-embed-text)
  ├── Save note → generate + store embedding
  ├── RAG query: embed → cosine sim → top-K → LLM context
  ├── ShivAIBloc + chat UI
  └── Model selection (Strategy pattern)
```
