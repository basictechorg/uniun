# uniun-backend — Relay Server

This is the Go server that sits between the internet and the Flutter app. It is a **Nostr relay** — meaning it speaks the Nostr WebSocket protocol and stores events. The Flutter app's Gateway isolate connects to it and syncs data.

---

## What Is a Nostr Relay in Simple Terms?

Think of it like a post office. Users (Flutter apps) send letters (Nostr events). The relay stores them and delivers them to anyone subscribed to that sender. The relay does not know what the letters mean — it just stores and routes them.

The relay speaks a simple protocol over WebSocket:
- `["EVENT", {...}]` — "store this event"
- `["REQ", "sub-id", {...filter}]` — "give me all events matching this filter"
- `["CLOSE", "sub-id"]` — "stop sending me those events"

---

## Tech Stack

| Component | What it is | Why |
|-----------|-----------|-----|
| **Go** | Language | Fast, low memory, good for network servers |
| **Khatru** (`github.com/fiatjaf/khatru`) | Nostr relay framework | Handles all WebSocket + NIP-01 protocol so we don't write it from scratch |
| **BadgerDB** | Primary storage | Embedded key-value store — no separate database process needed |
| **MySQL** | Optional mirror | For extra durability or analytics. BadgerDB is primary, MySQL gets a copy |
| **Blossom** | Media blob storage protocol | How the Flutter app uploads images (Brahma feature) |
| **Azure Blob Storage** | Where media files live | Cloud storage for photos uploaded by users |
| **zerolog** | Logging | Fast structured logging to stderr + optional log file |
| **Negentropy** | Set reconciliation | Enabled (`relay.Negentropy = true`) — efficient sync between relay and clients |

---

## File Map

```
uniun-backend/
├── main.go        — relay setup, BadgerDB + MySQL wiring, Blossom, graceful shutdown
├── config.go      — all settings from environment variables
├── logger.go      — zerolog setup: console + file logging, structured helpers
├── azure_blob.go  — Azure Blob Storage backend for Blossom media uploads
└── db/            — BadgerDB data files (auto-created at WORKING_DIR/db)
```

### main.go

Sets up the Khatru relay, wires storage backends, registers event + filter hooks, starts the WebSocket server. Key behaviours:

- **`relay.Negentropy = true`** — enables NIP-77 set reconciliation for efficient catch-up sync
- **`liveConnections`** — tracked via `OnConnect`/`OnDisconnect` hooks (used for health reporting)
- **`RejectEvent`** — currently logs all events and returns `false` (accepts everything). Needs kind allowlist before public launch.
- **`RejectFilter`** — currently accepts all subscription queries. Needs protection before public launch.
- **Blossom** — wired via `EventStoreBlobIndexWrapper` so blob metadata is indexed in BadgerDB alongside events

### config.go

All settings from environment variables with sensible defaults. No hardcoded values.

```
RELAY_BIND          — bind address (default: 0.0.0.0)
RELAY_PORT          — port (default: 8080)
RELAY_URL           — public WebSocket URL (e.g. wss://relay.uniun.app)
WORKING_DIR         — where BadgerDB files live (default: .)
MYSQL_DSN           — MySQL connection string (empty = disabled)
RELAY_NAME          — NIP-11 relay name
RELAY_DESCRIPTION   — NIP-11 description
RELAY_CONTACT       — NIP-11 contact
RELAY_PUBKEY        — NIP-11 operator pubkey (hex)
RELAY_ICON          — NIP-11 icon URL
RELAY_BANNER        — NIP-11 banner URL
AZURE_FOR_BLOSSOM   — true/false, enables Azure for media storage
AZURE_STORAGE_ACCOUNT_NAME — Azure account name
AZURE_STORAGE_ACCOUNT_KEY  — Azure account key
AZURE_BLOSSOM_CONTAINER    — container name (default: blossom)
LOG_LEVEL           — zerolog level: trace/debug/info/warn/error (default: info)
LOG_FILE            — path to log file (default: ./uniun.log); empty = no file
```

### logger.go

Structured logging via zerolog. Writes to stderr (console, human-readable) and optionally a log file simultaneously. Helper functions: `Trace`, `Debug`, `Info`, `Warn`, `Error`, `Fatal`, `Panic`. Key/value pairs are formatted correctly regardless of type (Stringer, error, []byte → hex, anything else → JSON).

### azure_blob.go

When `AZURE_FOR_BLOSSOM=true`, images uploaded via Blossom go to Azure Blob Storage.

Upload flow:
1. Flutter Brahma calls `PUT /upload` (Blossom BUD-01 protocol)
2. `azure_blob.go` receives file bytes + SHA-256 hash
3. Stores as `{sha256}.{ext}` in the Azure container
4. Returns the public Azure URL
5. Flutter embeds that URL in the Nostr event's `imeta` tag

---

## How the Flutter App Connects

```
Flutter App (UI isolate)
  └─ Isar (shared on-disk file)
        ↑ written by
Gateway isolate (lib/gateway/)
  └─ CentralRelayManager
        └─ WebSocketService(s)
              └─ WebSocket connection → ws://localhost:8080 (dev)
                                      → wss://relay.uniun.app (prod)
```

The Flutter UI **never** calls this relay directly. Only the Gateway isolate manages WebSocket connections. The UI reads/writes Isar only; Isar watchers bridge the two isolates.

---

## What Events This Relay Handles

| Kind | What it is | Used by | Status |
|------|-----------|---------|--------|
| 0 | User profile (name, avatar, bio) | Profile display, NIP-05 | ✅ Active |
| 1 | Short text note | Vishnu feed, threads, knowledge graph | ✅ Active |
| 7 | Reaction (like/emoji) | Note reactions | ✅ Active |
| 14 | DM chat message (Kind 14 rumor) | DMs (NIP-17) — schema done, UI pending | 🔲 UI pending |
| 13 | Seal (DM encryption layer 2) | DMs — full 3-layer wrap | 🔲 Future |
| 40 | Channel creation | Public channels (NIP-28) | ✅ Active |
| 41 | Channel metadata update | Public channels | ✅ Active |
| 42 | Channel message | Public channels + Private channels (E2EE payload inside content) | ✅ Active |
| 1059 | Gift wrap (DM outer envelope) | DMs — full 3-layer wrap | 🔲 Future |
| 10063 | User's Blossom server list | Media uploads | ✅ Active |
| 24242 | Blossom auth token | Media upload authorization | ✅ Active |

**Private channels** use Kind 42 on the relay — the MLS-encrypted payload is inside the `content` field. The relay is unaware of private channel semantics; it just stores and routes Kind 42 events like any other.

Not accepted (should be added to `RejectEvent` allowlist before public launch):
- Kind 6 (repost) — not implemented in Flutter client yet
- Everything else

---

## What Still Needs To Be Done

### Priority 1 — Add `RejectEvent` allowlist (relay is currently wide open)

```go
func RejectEvent(ctx context.Context, event *nostr.Event) (reject bool, msg string) {
    allowedKinds := map[int]bool{
        0: true, 1: true, 7: true, 13: true, 14: true,
        40: true, 41: true, 42: true, 1059: true, 10063: true, 24242: true,
    }
    if !allowedKinds[event.Kind] {
        return true, "blocked: kind not supported"
    }
    if len(event.Content) > 65536 {
        return true, "blocked: content too large"
    }
    if event.CreatedAt.Time().After(time.Now().Add(time.Hour)) {
        return true, "blocked: event timestamp too far in future"
    }
    return false, ""
}
```

### Priority 2 — Add `RejectFilter` protection

```go
func RejectFilter(ctx context.Context, filter nostr.Filter) (reject bool, msg string) {
    if filter.Authors == nil && filter.IDs == nil && len(filter.Tags) == 0 {
        return true, "blocked: filter too broad"
    }
    return false, ""
}
```

### Priority 3 — Local dev setup

- [ ] Create `.env.example` with all env vars documented
- [ ] Create `Dockerfile`
- [ ] Create `docker-compose.yml` (relay + optional MySQL)

### Priority 4 — Rate limiting (before public launch)

Per-pubkey: max 60 events/minute via in-memory sliding window in `RejectEvent`.

### Priority 5 — Production deployment

- [ ] Nginx reverse proxy for TLS (`wss://` required in prod)
- [ ] Set `RELAY_URL=wss://relay.yourdomain.com`
- [ ] `AZURE_FOR_BLOSSOM=true` + Azure credentials
- [ ] `MYSQL_DSN` for durable event mirror
- [ ] `LOG_LEVEL=warn` to reduce noise
- [ ] Docker container with restart policy

---

## Quick Start (Local Development)

```bash
cd uniun-backend

# 1. Copy env and fill in values (once .env.example exists)
cp .env.example .env

# 2. Run
go run .

# Relay is now at ws://localhost:8080
# NIP-11 info: curl -H "Accept: application/nostr+json" http://localhost:8080/
```

---

## Architecture Position

```
Flutter App (Vishnu, Brahma, Shiv, Channels, Private Channels, DMs)
      ↕ WebSocket NIP-01 + NIP-77 (Negentropy)
uniun-backend  (Khatru + BadgerDB)
      ↕ optional write mirror
MySQL

Flutter Brahma (image attach)
      → PUT /upload  (Blossom BUD-01)
uniun-backend Blossom handler
      → Azure Blob Storage → public URL → imeta tag in Nostr event
```

---

## What NOT to Change

- Do not modify `Gateway` isolate on the Flutter side — that is a separate team's code.
- Do not add custom REST endpoints for app-specific logic — the relay speaks Nostr protocol only.
- Do not store user private keys anywhere on the relay — it only sees public keys and signed events.
- Private channel MLS encryption is handled entirely in the Flutter app — the relay never decrypts anything.
