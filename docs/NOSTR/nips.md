# UNIUN — Nostr NIP Stack

UNIUN keeps the NIP surface minimal. Only the NIPs listed here are implemented or planned. Everything else is out of scope.

---

## NIP-01 — Base Protocol

**What it is:** The foundation. Defines the Nostr event format, WebSocket message types (`EVENT`, `REQ`, `CLOSE`, `OK`, `NOTICE`, `EOSE`), and subscription filter syntax.

**How UNIUN uses it:**
- Every note, profile, channel, and message is a `NostrEvent` (id, pubkey, kind, tags, content, created_at, sig).
- The Gateway isolate (`lib/gateway/`) speaks raw NIP-01 over each relay's WebSocket: sends `["REQ", subId, filter]` to subscribe and `["EVENT", {...}]` to publish.
- `["OK"]` ACK responses advance the outbound queue cursor (`lib/gateway/outbound/outbound_pump.dart`).

**The relay conversation, concretely:**
```
Client → Relay: ["REQ", "sub_id", {filter}]     ← subscribe
Relay  → Client: ["EVENT", "sub_id", {event}]   ← events matching filter
Relay  → Client: ["EOSE", "sub_id"]             ← end of stored events, live updates start
Client → Relay: ["EVENT", {event}]              ← publish an event
Relay  → Client: ["OK", "event_id", true, ""]   ← publish confirmed
Client → Relay: ["CLOSE", "sub_id"]             ← unsubscribe
```
Multiple filters in one `REQ` are ORed together; fields within one filter are ANDed.

**Event format:**
```json
{
  "id":         "<SHA256 of canonical serialization>",
  "pubkey":     "<secp256k1 pubkey hex>",
  "created_at": 1700000000,
  "kind":       1,
  "tags":       [["e", "..."], ["p", "..."], ["t", "..."]],
  "content":    "note text",
  "sig":        "<Schnorr signature>"
}
```

---

## NIP-10 — Reply Threading

**What it is:** Defines how `e` tags are used to build reply threads. Introduces `root`, `reply`, and `mention` markers on e-tags.

**How UNIUN uses it:**
- Every incoming Kind 1 event is parsed for NIP-10 markers in `WebSocketService._parseNoteModel()`.
- `["e", id, relayUrl, "root"]` → stored as `NoteModel.rootEventId`
- `["e", id, relayUrl, "reply"]` → stored as `NoteModel.replyToEventId`
- `["e", id, relayUrl, "mention"]` → stored in `NoteModel.eTagRefs`
- Reply count = direct `replyToEventId` children + root-tag-only children (no mentions).
- Knowledge graph edges = all eTagRefs (including root/reply/mention).

**Note roles (derived, never stored as a field):**

| Role | Condition | Where shown |
|------|-----------|-------------|
| Feed post | `rootEventId == null` | Vishnu feed |
| Reply | `rootEventId != null` | Thread view |
| Reference | `type == NoteType.reference` | Graph view |

---

## NIP-28 — Public Groups

**What it is:** Defines public group chat via three event kinds: Kind 40 (creation), Kind 41 (metadata update), Kind 42 (message). The NIP itself calls this "public chat channels" — UNIUN's own code, routes, and UI all say "Group."

**How UNIUN uses it — the app calls this feature "Groups," not "Channels":**
- `CreateGroupUseCase` builds and signs a Kind 40 event. The Kind 40 event's `id` **is** the group id — permanently. Never generate a separate id.
- Group metadata (name, about, picture) is JSON-encoded in the Kind 40 `content` field.
- Kind 41 = metadata update, applied gateway-side by `Kind41Handler` only if `event.pubkey == group.creatorPubKey` and the event is newer than the stored `updatedAt`.
- Kind 42 messages tag `["e", groupId, "", "root"]`.
- Each joined group is a `GroupModel` row in Isar (`@Name('Channel')` on disk — a preserved pre-rename schema name, not a live class name). The Gateway routes Kind 40-42 events to group-specific relays stored in `GroupModel.relays` (temporary `WebSocketService` instances, 5 min TTL).
- Private groups exist too, via NIP-29 (Kind 9021-9025 family) + MLS encryption — not covered in this file since it's a different NIP; see `docs/Messaging/GROUPS.md`.

**Relay subscriptions for groups** (`lib/gateway/subscriptions/providers/groups_subscription.dart`):
```json
{"kinds": [42], "#e": ["...joined groupIds"], "since": "..."}
```
plus uncapped companion filters `{"kinds":[40],"ids":[...groupIds]}` and `{"kinds":[41],"#e":[...groupIds]}`. Full depth: `docs/Messaging/GROUPS.md`.

---

## NIP-29 — Private Groups (MLS-encrypted)

**What it is:** Relay-based group membership/routing via `["h", groupId]` tags; UNIUN layers MLS (`openmls`) end-to-end encryption on top for the actual message content.

**How UNIUN uses it:**
- Kind 9021 = join request (carries an MLS key package), 9023 = application message (MLS-encrypted, `kPrivateGroupKind`), 9024 = Welcome, 9025 = Commit, 9002 = group metadata.
- Membership changes (adding a member) go through `MarmotMlsService.addMembers` before the Welcome/Commit pair is published — the relay never sees plaintext membership or message content, only the `h`-tagged routing.
- Full depth, including the admin-approval flow: `docs/Messaging/GROUPS.md`.

---

## NIP-17 — Private Direct Messages

**What it is:** Defines Kind 14 as the rumor (actual DM content, unsigned) and the three-layer encryption structure for private 1:1 messaging.

**How UNIUN uses it — fully shipped, not MVP-only:**
- Kind 14 = actual message content (unsigned rumor) → NIP-44 encrypt → Kind 13 (seal, signed) → NIP-44 encrypt with an ephemeral key → Kind 1059 (gift wrap, the only thing that ever touches a relay).
- Only `["p", recipientPubkey]` is visible on the relay — the seal and rumor never are.
- Subscription: `{"kinds": [1059], "#p": ["myPubkey"]}` for receiving DMs.
- Unread tracking uses the same unified `UnreadNoteModel` every surface uses — there is no separate `DMReadStateModel`.
- DM content lives in the unified `Note` Isar collection (kind 14/15, discriminated by `conversationId`) — not a separate `DmMessageModel`. Full depth: `docs/Messaging/DMS.md`.

---

## NIP-44 — Encryption

**What it is:** The encryption standard used for private message payloads — ChaCha20-Poly1305 + HMAC-SHA256, keyed via secp256k1 ECDH + HKDF.

**How UNIUN uses it:**
- Encrypts every layer of the Kind 14 → 13 → 1059 gift-wrap chain (see NIP-17 above) — this is live, not a future plan.
- Replaces legacy NIP-04 (AES-CBC) — NIP-04 is explicitly NOT used.

---

## NIP-05 — Human-Readable Identifiers

**What it is:** Maps a Nostr pubkey to a DNS-based human-readable identifier (e.g. `user@domain.com`).

**How UNIUN uses it:**
- Stored in `ProfileModel.nip05` (Kind 0 metadata field).
- Displayed in profile view and channel member lists.
- Resolved by looking up `https://<domain>/.well-known/nostr.json?name=<name>`.
- Primarily received from profiles published by other apps on the network — not generated by UNIUN itself.

---

## NIP-59 — Gift Wrap

**What it is:** The outer envelope (Kind 1059) that hides who a DM's rumor/seal actually belongs to on the relay.

**How UNIUN uses it:** The outermost layer of the NIP-17 DM chain described above — shipped, not future scope. Only `["p", recipient]` is visible; the wrapped content is opaque to the relay and to anyone but the recipient.

---

## NIPs Explicitly NOT Used

| NIP | Why excluded |
|-----|--------------|
| NIP-09 | Event deletion — **permanently excluded**. Feed freedom is a core UNIUN principle. Notes are forever. Never implement. |
| NIP-04 | Legacy DM encryption (AES-CBC) — superseded by NIP-44. |
| NIP-11 | Relay info advertisement — handled automatically by Khatru on the relay side; Flutter client does not implement it. |
| NIP-18 | Reposts — not a standalone NIP-18 repost flow; sharing/quoting is UNIUN's own embed-by-value `embeddedNoteJson` design (see CLAUDE.md's "Sharing" section), not this NIP. |
| NIP-51 | Lists (saved notes, mute lists) — saved notes are local-only in Isar, not published as Nostr events. |
| NIP-65 | Relay list metadata (Kind 10002) — relay list is managed locally in `RelayModel` (Isar), not via Nostr events. |
