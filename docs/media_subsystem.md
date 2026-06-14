# UNIUN Media Subsystem

How photos, videos and files travel from one device through our relay to another. Read top to bottom and you'll be able to answer any question about it.

---

## 1. What problem does this solve?

A Nostr event is a tiny signed JSON blob. Putting raw photo bytes inside it would be terrible:
- Every relay would store and forward megabytes per post.
- Most relays cap event size at 64–256 KB and would just reject big events.
- The same picture quoted into ten chats would be transmitted ten times.

So Nostr splits the job in two:

| Layer | Carries | Stored by | Format |
|-------|---------|-----------|--------|
| **Nostr relay** | Tiny **signed events** that *reference* a blob by its hash | Khatru + BadgerDB | JSON over WebSocket |
| **Blossom server** | The actual **bytes** of the blob | Khatru blossom + Azure Blob Storage | Raw HTTP PUT / GET |

Our backend in `uniun-backend/` runs **both** services on the same host (`dev.uniun.in:8080`) — `wss://` is the relay, `https://` is Blossom — but they're logically independent.

---

## 2. NIPs used

### NIP-92 — Inline media metadata

Defines the `imeta` tag that attaches blob metadata to *any* Nostr event:

```
["imeta",
  "url https://dev.uniun.in:8080/<sha256>.jpg",
  "m image/jpeg",
  "x <sha256-hex>",
  "size 482133",
  "dim 1920x1080",
  "blurhash LKO2?U%2Tw=w]~RBVZRi};RPxuwH"
]
```

Each sub-string after the tag name is `key value`. Multiple `imeta` tags = multiple attachments.

The `m` (mime) field is **mime-agnostic** — `image/jpeg`, `video/mp4`, `audio/ogg`, `application/pdf` all valid.

### NIP-B7 — Blossom

The HTTP protocol for content-addressed blob storage. Three BUDs we use:

- **BUD-01** — the upload / download / list / delete endpoints. Auth via Kind 24242.
- **BUD-02** — list / delete (we use list, not delete in v1).
- **BUD-03** — Kind 10063 `User Server List`. Tells other clients which Blossom servers a user prefers.

### Kind 24242 — Blossom auth

A signed Nostr event that proves to a Blossom server "this user authorized this action on this blob right now". Not stored anywhere — it's sent inline in the HTTP `Authorization` header as `Nostr <base64(JSON event)>`.

```jsonc
{
  "kind": 24242,
  "created_at": <unixSec>,
  "tags": [
    ["t", "upload"],                 // or "get" | "list" | "delete"
    ["x", "<sha256-of-blob>"],       // omitted for list
    ["expiration", "<unixSec+300>"]  // 5-minute window
  ],
  "content": "Upload",
  "pubkey": "<own>", "id": "...", "sig": "..."
}
```

### Kind 10063 — User server list (BUD-03)

Replaceable per-pubkey event listing the user's preferred Blossom servers.

```jsonc
{
  "kind": 10063,
  "tags": [["server", "https://dev.uniun.in:8080"]],
  "content": ""
}
```

We publish one on first upload so a second device knows where to fetch the user's media from.

### Kind 1 / Kind 42 — host events

The text note (`kind: 1`) or channel message (`kind: 42`) is what actually goes on the timeline. Its `tags` array carries one `imeta` per attachment. The host event is what gets re-broadcast; the bytes never leave the Blossom server until someone explicitly downloads them.

---

## 3. Big picture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            UNIUN CLIENT (Flutter)                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Presentation                                                      │   │
│  │   BrahmaCreateBloc · NoteCard · MediaAttachmentView · Gallery    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │ use cases                                 │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Domain                                                            │   │
│  │   NoteEntity · MediaBlobEntity · MediaRepository ports            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              │                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Data                                                              │   │
│  │   ┌────────────┐  ┌─────────────┐  ┌──────────────────────┐     │   │
│  │   │ Isar       │  │ BlossomClient│ │ MediaCacheDataSource │     │   │
│  │   │ MediaBlob  │  │  (HTTP)      │ │  (path_provider)     │     │   │
│  │   │ NoteMedia… │  │              │ │                      │     │   │
│  │   │ UserServer…│  │              │ │ media/<sha>.<ext>    │     │   │
│  │   └────────────┘  └─────────────┘  └──────────────────────┘     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                              ↑ writes Isar                               │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Gateway isolate                                                   │   │
│  │   inbound handlers (Kind1/Kind42/Kind10063)  ·  EventQueue        │   │
│  │   CleanupManager (every 6h)                                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────┬─────────────────────┬──────────────────────────────┘
                     │ WSS                 │ HTTPS
                     │ Nostr (events)      │ Blossom (bytes)
┌────────────────────▼─────────────────────▼──────────────────────────────┐
│                         UNIUN BACKEND (Go)                               │
│   ┌──────────────────────────┐    ┌────────────────────────────┐        │
│   │ Khatru relay             │    │ Khatru blossom handler     │        │
│   │  · BadgerDB (events)     │    │  PUT/GET/HEAD/list/delete  │        │
│   │  · MySQL mirror          │    │                            │        │
│   └──────────────────────────┘    └─────────────┬──────────────┘        │
│                                                  │                        │
│                                                  ▼                        │
│                                       ┌────────────────────┐             │
│                                       │ Azure Blob Storage │             │
│                                       └────────────────────┘             │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 4. End-to-end flows

### 4.1 Upload — sender publishes a note with a photo

```
┌─ Compose page (graph_compose_page.dart) ─────────────────────────────┐
│                                                                       │
│  User taps 📷 ─► showComposeMediaSheet(context)                       │
│                       │                                               │
│                       ▼                                               │
│            ┌─────────────────────────────┐                            │
│            │  Bottom sheet               │                            │
│            │   • Photo                   │                            │
│            │   • Video                   │                            │
│            │   • File                    │                            │
│            └─────────────┬───────────────┘                            │
│                          │ pick Photo                                 │
│                          ▼                                            │
│             ImagePicker.pickImage(gallery)                            │
│                          │                                            │
│                          ▼                                            │
│            ┌────────────────────────────────┐                         │
│            │ ImageCompressor.compressToTarget│                        │
│            │   target = 950 KB              │                         │
│            │   88q/2048 → 30q/800 schedule  │                         │
│            └────────────┬───────────────────┘                         │
│                         │  ok                                         │
│                         ▼                                             │
│         decode dim via dart:ui (width × height)                       │
│                         │                                             │
│                         ▼                                             │
│  bloc.add(UploadAndAttachMediaEvent(bytes, mime, dim, filename))      │
└──────────────────────────────┬────────────────────────────────────────┘
                               │
┌──────────────────────────────▼────────────────────────────────────────┐
│ BrahmaCreateBloc._onUploadAndAttachMedia                              │
│   emit(isAttachingMedia=true)   ─►   composer shows spinner            │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐    │
│   │ MediaRepositoryImpl.uploadBytes                              │    │
│   │   sha = sha256(bytes)                                        │    │
│   │   server = AppConstants.kUniunBlossom                        │    │
│   │                                                              │    │
│   │   HEAD /<sha>           ┐                                    │    │
│   │     200 → skip PUT (server already has it; dedup)            │    │
│   │     404 → PUT /upload   ┘                                    │    │
│   │         Authorization: Nostr <base64 Kind-24242 event>       │    │
│   │         Content-Type: image/jpeg                             │    │
│   │         body: <bytes>                                        │    │
│   │   ─► response: { url, sha256, size, type }                   │    │
│   │       NOTE: response.url is *ignored*. Khatru derives it from│    │
│   │       relay.URL which is `wss://…` — useless for HTTP fetch. │    │
│   │       We build publicUrl from `kUniunBlossom` ourselves.     │    │
│   │                                                              │    │
│   │   write local cache: media/<sha>.jpg                         │    │
│   │   upsert MediaBlobModel (sha, mime, dim, localPath, …)       │    │
│   │   first upload only: setServers([primary]) → Kind 10063      │    │
│   └──────────────────────────────────────────────────────────────┘    │
│                                                                        │
│   state.attachedMedia += blob                                          │
│   emit(isAttachingMedia=false)   ─►   thumbnail shows, send unlocks    │
└────────────────────────────────────────────────────────────────────────┘

User types text · taps Send

┌─ BrahmaCreateBloc._onSubmitNote ───────────────────────────────────────┐
│                                                                        │
│   tags = buildNoteTags(root, reply, mentions, hashtags)                │
│   for each attached blob:                                              │
│      tags += ["imeta", "url …", "m …", "x …", "size …",                │
│               "dim WxH", "blurhash …"]                                 │
│                                                                        │
│   signed = Event.from(kind:1, tags:tags, content, privkey)             │
│                                                                        │
│   NoteEntity built with hasMedia=true                                  │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐    │
│   │ PublishMediaNoteUseCase                                      │    │
│   │   noteRepo.saveNote(entity) → NoteModel(hasMedia:true)       │    │
│   │   for each sha:                                              │    │
│   │     mediaRepo.linkNoteRef(sha, noteId) → NoteMediaRefModel   │    │
│   │   eventQueue.enqueueSignedEvent(                             │    │
│   │       content = full signed JSON,                            │    │
│   │       rawPassthrough: true)                                  │    │
│   └──────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘

Gateway isolate · OutboundPump
   row.isRawPassthroughEvent == true → toRawRelayMessage()
   WebSocketService.send(["EVENT", { …signed JSON with imeta… }])
   relay: ["OK", id, true]  ✓
```

### 4.2 Inbound — another device receives the note

```
Relay pushes ["EVENT", "feed_notes", { kind:1, tags:[imeta,…], … }]
       │
       ▼
InboundBus → Kind1NoteHandler
       │
       ├─► _parseNoteModel(event)                       — text, e-tags, q-tag
       ├─► model.hasMedia = ImetaParser.hasImeta(event) — fast O(tags) scan
       │
       ├─► writeTxn:
       │     noteModels.put(model)
       │     ImetaParser.persistInTxn(noteEventId, event):
       │       for each imeta:
       │         upsert MediaBlobModel(sha, mime, dim, blurhash,
       │                                serverUrls, localPath=null,
       │                                lastSeenAt=now)
       │         insert NoteMediaRefModel(noteId, sha) [idempotent]
       │
       └─► unread row, reply edges (existing logic)
```

At this point the receiver's Isar has **metadata only** — no bytes were transferred. The note appears in the feed; the photo shows as a **blurhash placeholder + Download button**.

### 4.3 Read — viewer scrolls past the note

```
Vishnu feed loads page
       │
       ▼
FeedRepository.getUnseenQueue / getSeen
       │ rows from NoteModel (kind 1/42, author allow-list)
       ▼
NoteResolverRepository.enrichWithQuotes
       │
       ├─► quote-target NoteEntity lookup (single bulk query)
       ├─► NoteAttachmentsEnricher.enrichAll([page, quoteTargets])
       │     • one query into NoteMediaRefModel filtered to media noteIds
       │     • one query into MediaBlobModel for unique sha256s
       │     • assemble in memory
       │
       ▼
List<NoteEntity> arrives at BLoC, each entity has note.attachments populated

NoteCard.build
       │
       └─► if (note.hasMedia) MediaAttachmentView(note, compact: true)
                                     │
                                     ▼
            _AttachmentTile          (StatefulWidget)
                                     │
                  ┌──────────────────┴───────────────────┐
                  │ localPath != null                    │ localPath == null
                  ▼                                      ▼
            Image.file(...)                  blurhash + Download button
            BoxFit.cover                     tap → DownloadMediaUseCase
            height ≤ 280px (compact)
                                                       │
                                                       ▼
                                BlossomClient.download(server, sha)
                                      cache.write(sha, ext, bytes)
                                      upsert MediaBlobModel(localPath set)
                                      setState in tile → image shows
```

### 4.4 Gallery — user opens Settings → Storage → Media

```
MediaGalleryCubit.load
       │
       └─► WatchMediaUseCase
              ▼
       MediaRepository.watchAll(filter)
              ▼
       isar.mediaBlobModels.where().sortByLastSeenAtDesc()
              .watch(fireImmediately: true)
              .map(filter)

Each tile = MediaTile widget
  status badges: ⭐ pinned · ✅ on-device · ⬇️ remote-only
  long-press   : Download / Pin / Remove from device

Tap → MediaDetailPage(sha256)
       loads MediaBlobModel + getReferencingNoteIds
       shows full preview + metadata + action row
```

### 4.5 GC — every 6 hours in the gateway isolate

```
CleanupManager.runOnce
   ├─► Phase A: note eviction
   │     for each Kind 1 older than 7d:
   │       skip if authorPubkey == ownPubkey      (own forever)
   │       skip if in SavedNoteModel              (saved forever)
   │       else delete from NoteModel
   │     same logic for Kind 42 / >3d
   │
   └─► Phase B: media GC
         for each MediaBlobModel where pinned == false:
           count = NoteMediaRefModel.where(sha).count
           if count == 0:
             delete local file (media/<sha>.ext)
             delete MediaBlobModel row
   (Backend keeps the bytes on Azure forever — nothing here calls DELETE /sha)
```

---

## 5. Data model

### 5.1 Isar collections

```
NoteModel                  (existing)
├── eventId   (unique)
├── content, sig, authorPubkey, …
├── hasMedia  (bool, default false) — NEW: fast gate for UI
└── … (kind, threading, etc.)

MediaBlobModel             (new — one row per content-addressed blob)
├── id        (auto)
├── sha256    (unique)
├── mime                       default 'application/octet-stream'
├── sizeBytes                  default 0
├── width / height / blurhash  nullable
├── serverUrls                 default []
├── localPath                  null until downloaded
├── downloadedAt               null until downloaded
├── lastSeenAt                 indexed — gallery sort
└── pinned                     indexed — GC skip flag

NoteMediaRefModel          (new — join table)
├── noteEventId   indexed
└── mediaSha256   indexed
                  (composite uniqueness enforced in code)

UserServerListModel        (new — single-row, id=0)
├── serverUrls                 default []
└── lastSyncedCreatedAt        nullable — LWW for inbound Kind 10063
```

### 5.2 Domain entity enrichment

`NoteEntity` carries attachments pre-resolved by the data layer — same pattern as `cachedReplyCount`, `referenceCount`, `quotedNote`:

```dart
@freezed
abstract class NoteEntity with _$NoteEntity {
  const factory NoteEntity({
    // … existing fields
    @Default(false) bool hasMedia,
    @Default([])    List<MediaBlobEntity> attachments,
    // attachments is excluded from JSON via @JsonKey(includeFromJson: false,
    // includeToJson: false) — it's an in-memory enrichment, not wire data.
  }) = _NoteEntity;
}
```

UI widgets read `note.attachments` directly; nobody hits Isar from a card.

### 5.3 Retention table

| What | Retention |
|------|-----------|
| Own notes (any kind) | Forever |
| Saved notes (`SavedNoteModel`) | Forever |
| Kind 1 (regular) | 7 days |
| Kind 42 (channel) | 3 days |
| DM / private channel content | Forever |
| MediaBlobModel — pinned | Forever |
| MediaBlobModel — any note still references it | Forever (kept until last reference GCs) |
| MediaBlobModel — zero references, not pinned | GC'd on next cleanup tick |

---

## 6. UI behavior

### 6.1 Attachment tile sizing (Twitter/X pattern)

`MediaAttachmentView({required note, compact = true})` — single flag.

| Surface | Mode | Max height |
|---------|------|------------|
| Vishnu / channel / private channel feed | compact | **280 px** |
| Embedded quoted note | compact | 280 px |
| DM bubble (in / out) | compact | 280 px |
| Thread parent (`LargeNoteCard`) | **expanded** | **480 px** |
| Media detail page | n/a | full native aspect |

Layout in `_AttachmentTile`:
```dart
final naturalH = parentWidth / aspect;
final height = naturalH.clamp(0.0, maxH);
SizedBox(width: parentWidth, height: height,
         child: Image.file(..., fit: BoxFit.cover))
```

Wide / panoramic images render at natural aspect. Portraits and squares get cropped from top + bottom equally so the card stays scannable. The full image is always one tap away on the detail page.

### 6.2 Composer

`UniunComposer` exposes `onAttachMedia` + `attachments` + `isAttachingMedia` props.

- Round media button (📷) sits next to the reference and markdown buttons.
- A 72×72 thumbnail strip appears above the text field for each attached blob (× to remove).
- A 72×72 spinner tile shows while an upload is in flight.
- Send button disables while `isAttachingMedia` is true — prevents publishing a note before the imeta is ready.

### 6.3 Gallery

`Settings → Storage → Media` opens `MediaGalleryPage`.

Filter chips: **All · Images · Videos · Audio · Files · Pinned**. (No "On device" chip — the Download button on each tile already conveys cached-ness.)

Each tile shows pin / cache badges; long-press opens an action sheet (Download / Pin / Remove from device). Tap → `MediaDetailPage` for full preview + metadata + Copy sha / Copy URL.

---

## 7. Capability matrix — what works today

| Capability | Server | Nostr | Client | Status |
|-----------|--------|-------|--------|--------|
| Upload image (≤950 KB after compression) | ✓ | ✓ | ✓ | **Works** |
| Auto-compress image to fit cap | n/a | n/a | ✓ (`flutter_image_compress`) | **Works** |
| Display image in feed (compact) | n/a | n/a | ✓ | **Works** |
| Display image in thread (expanded) | n/a | n/a | ✓ | **Works** |
| Display image in DM / quote / channel | n/a | n/a | ✓ | **Works** |
| Blurhash placeholder before download | n/a | ✓ (NIP-92 field) | ✓ render, ✗ encode | **Render works**, we don't compute blurhash on upload yet — placeholder falls back to mime icon |
| Multi-device sync of own-server list | ✓ | ✓ (Kind 10063) | ✓ | **Works** |
| Dedup via sha256 (HEAD before PUT) | ✓ | n/a | ✓ | **Works** |
| Pin / GC retention | n/a | n/a | ✓ | **Works** |
| Upload video (≤950 KB) | ✓ (mime-agnostic) | ✓ (NIP-92 `m video/*`) | ✓ upload works | **Works for tiny clips**. We don't transcode — anything bigger gets a snackbar |
| Render inline video player | n/a | n/a | ✗ | **Not yet** — tile shows movie icon; tap goes to detail page; detail also shows icon, no player |
| Upload arbitrary file (≤950 KB) | ✓ | ✓ (NIP-92 `m application/*`) | ✓ upload works | **Works for small files** |
| Open / preview file (PDF, doc, …) | n/a | n/a | ✗ | **Not yet** — file icon only |
| Large uploads (>950 KB) | ✓ Khatru can handle, but nginx caps at 1 MB by default | ✓ | ✗ — client refuses | **Blocked at nginx**. Two options: (a) bump `client_max_body_size` on the proxy; (b) keep the 950 KB cap and do background chunked upload in v2 |

### Plain-English answer to the question

**Does our backend support video / files?**
Yes. Khatru's blossom handler is **content-agnostic** — it hashes whatever bytes you PUT, regardless of mime. Azure Blob Storage stores whatever bytes the handler hands it. The relay accepts any Kind 1 / Kind 42 event with `imeta` tags regardless of the mime field.

**Does Nostr support video / files?**
Yes. NIP-92 makes no assumption about mime type — `image/*`, `video/*`, `audio/*`, `application/*` all valid.

**So what's missing?**
1. **nginx default cap of 1 MB** in front of the relay. Bigger videos hit this before reaching Khatru. Until raised, we cap the client at 950 KB.
2. **No inline video player** in the client (`MediaAttachmentView` shows a movie icon for `video/*`). Adding one is a UI-layer change only — the upload / download / cache plumbing is mime-agnostic and already works.
3. **No file viewer** for arbitrary mime types (PDF, doc, etc.). Same shape as above — tap → detail page → "Open externally" via `open_file` is a future addition.

So today: **images full end-to-end**. Videos/files are correctly plumbed through every layer; they're just bottlenecked at nginx and don't have rich preview UI yet. Lifting both is incremental, not a redesign.

---

## 8. Wire-format cheat sheet

### Kind 1 with one image attached (what flows to the relay)

```jsonc
{
  "id":   "<sha256 of canonical serialization>",
  "kind": 1,
  "created_at": 1789012345,
  "pubkey": "<own>",
  "tags": [
    ["e", "<root>",  "", "root"],
    ["p", "<mention>"],
    ["t", "uniun"],
    ["imeta",
      "url https://dev.uniun.in:8080/abc…123.jpg",
      "m image/jpeg",
      "x abc…123",
      "size 482133",
      "dim 1920x1080"
    ]
  ],
  "content": "look at this view!",
  "sig": "<schnorr signature>"
}
```

### Kind 24242 Blossom auth (sent as HTTP header, never to the relay)

```
Authorization: Nostr <base64({
  "kind":24242, "content":"Upload",
  "tags":[["t","upload"],["x","abc…123"],["expiration","1789012345"]],
  "pubkey":"<own>", "id":"…", "sig":"…"
})>
```

### Kind 10063 (BUD-03 user server list)

```jsonc
{
  "kind": 10063,
  "tags": [["server", "https://dev.uniun.in:8080"]],
  "content": ""
}
```

### Raw-passthrough enqueue

`EventQueueModel` rows with `rawPassthrough = true` (set by `PublishMediaNoteUseCase` and by the Kind 10063 publish path) skip the shaped serializer. Their full signed JSON is stored verbatim in the `content` column and emitted via `toRawRelayMessage()`. Required because the shaped serializer rebuilds tags in a fixed order (e → p → t → q → k) and can't emit `imeta` or `server` without re-hashing the event id (which would break the signature).

---

## 9. File map

```
Domain                                                            
├── lib/domain/entities/media/media_blob_entity.dart              freezed entity
├── lib/domain/entities/media/media_dim.dart                      freezed (w,h)
├── lib/domain/entities/media/media_filter.dart                   gallery filter
├── lib/domain/entities/note/note_entity.dart                     +attachments
├── lib/domain/repositories/media_repository.dart                 abstract
├── lib/domain/repositories/user_server_list_repository.dart      abstract
├── lib/domain/usecases/media_usecases.dart                       10 use cases

Data                                                              
├── lib/data/models/media/media_blob_model.dart                   manifest
├── lib/data/models/media/note_media_ref_model.dart               join table
├── lib/data/models/user_server_list_model.dart                   single-row
├── lib/data/datasources/blossom_client.dart                      HTTP client
├── lib/data/datasources/media_cache_data_source.dart             path_provider
├── lib/data/repositories/media_repository_impl.dart              orchestrator
├── lib/data/repositories/user_server_list_repository_impl.dart   K10063
├── lib/data/repositories/note_attachments_enricher.dart          bulk JOIN

Gateway                                                           
├── lib/gateway/inbound/imeta_parser.dart                         parse + persist
├── lib/gateway/inbound/handlers/kind10063_user_server_list_handler.dart
├── lib/gateway/cleanup/cleanup_manager.dart                      6h GC

Presentation                                                      
├── lib/common/widgets/note_card/media_attachment_view.dart       Twitter-sized
├── lib/features/media/cubit/media_gallery_cubit.dart
├── lib/features/media/cubit/media_detail_cubit.dart
├── lib/features/media/pages/media_gallery_page.dart
├── lib/features/media/pages/media_detail_page.dart
├── lib/features/media/widgets/media_tile.dart
├── lib/features/brahma/graph/widgets/compose_media_sheet.dart    pickers
├── lib/features/settings/widgets/media_row.dart                  Storage→Media
└── lib/common/snackbar.dart                                       AppSnackbar

Core                                                              
├── lib/core/constants/app_constants.dart                         kMaxUploadBytes
└── lib/core/utils/image_compressor.dart                          iterative JPEG
```

---

## 10. Verification checklist

End-to-end smoke, run in order. Most need two devices signed into the same identity.

1. **Schema migration** — `flutter pub run build_runner build --delete-conflicting-outputs` clean. App boots without Isar exceptions.
2. **Upload + publish** — attach a photo in Brahma, publish. Check:
   - composer shows spinner tile, then real thumbnail
   - send button blocked during upload, unlocked after
   - `EventQueueModel` row with `kind: 1`, `rawPassthrough: true`, JSON containing `imeta`
   - Backend Azure container has `<sha256>.jpg`
   - Local `media/<sha256>.jpg` exists
   - Gallery shows the new blob with ✅ on-device badge
3. **Render across surfaces** — same note in Vishnu (compact), in thread page (expanded), quoted by another note (compact in `EmbeddedNoteCard`).
4. **Inbound on second device** — relay streams the note. Check:
   - `NoteMediaRefModel` row written
   - `MediaBlobModel` row with `localPath == null`
   - Note card renders blurhash placeholder + Download button (or mime icon if no blurhash)
5. **Tap Download** — bytes arrive, tile flips to image. Second tap on a different note that references the same sha → no network, served from cache.
6. **Kind 10063** — on the second device, sign in. After Gateway syncs, `UserServerListModel.serverUrls` populated. Future uploads against that server.
7. **Compression** — pick a 5 MB JPEG. Compressor walks the schedule, fits under 950 KB, uploads. No 413 from nginx.
8. **Hard-reject paths** — pick a 4 MB video → snackbar "File too large (4096 KB). Max 950 KB."
9. **GC** — fake-age a Kind 1 note past 7 days. Run `CleanupManager.runOnce()`. Blob with `pinned: false` and no other ref → file deleted + row deleted. Pin a blob → survives GC even with no refs.
10. **Static checks** — `flutter analyze lib/` clean. No hardcoded English (all via `AppLocalizations`).

---

## 10.5. Gotchas (production issues we've actually hit)

### Khatru's `descriptor.url` is a `wss://` URL

Khatru's blossom plugin is constructed as `blossom.New(relay, config.RelayURL)`. `RelayURL` is the relay's *WebSocket* URL (e.g. `wss://dev.uniun.in:8080`). The plugin uses that string verbatim when it returns blob descriptors, so `descriptor.url` ends up looking like:

```
wss://dev.uniun.in:8080/<sha256>.<ext>
```

If the publisher stored that and embedded it in the `imeta` tag, every other device would try to `http.get('wss://…')` and fail — silently before the snackbar fix below.

Both legs are now defended:

- **Outbound** (`MediaRepositoryImpl.uploadBytes`): the response's `url` field is discarded. We always build `publicUrl` from `kUniunBlossom` (the HTTPS base in `AppConstants`). The imeta tag carries `https://…` regardless of what the server returned.
- **Inbound / legacy rows** (`MediaRepositoryImpl._serverBase`): coerces `wss://` → `https://` and `ws://` → `http://` before any HTTP call, so notes received from older clients (or future relays with the same bug) still resolve to a fetchable origin.

If you ever change blob URL construction, keep both halves consistent.

### Silent download failure was invisible during testing

`MediaAttachmentView._download` used to do `res.fold((_) {}, …)` — the `Either<Failure, …>` Left was swallowed. Cross-device downloads could fail for any reason (the `wss://` bug, an expired auth token, a network blip) and the UI would simply… do nothing. No spinner change, no error.

Now it routes through `AppSnackbar.error(context, f.toMessage())` so the failure is visible to the user (and to whoever is QAing on a second device). If you're adding a new download trigger, keep this pattern: surface the Left, don't swallow it.

---

## 11. Open / deferred items

| Item | Why deferred |
|------|--------------|
| Blurhash encode on upload | `flutter_image_compress` doesn't ship an encoder. Adding `blurhash_dart` for encode + `compute()` for isolate-safe execution is straightforward when wanted. Until then, missing blurhash falls back to a mime-icon placeholder. |
| Inline video playback | Needs `video_player` or `chewie`. Same data flow; UI-only addition in `MediaAttachmentView`. |
| In-app file preview (PDF / doc) | `open_file` or a custom viewer per mime. Same data flow. |
| Background / chunked upload | For files >950 KB we'd need either (a) raise nginx cap and accept synchronous PUT, or (b) implement chunked PUT (Blossom spec extension). |
| Multi-server fan-out (BUD-03) | v1 publishes the single backend URL in Kind 10063. Fan-out to a list of servers + mirror fallback is a v2. |
| BUD-04 mirror | Cross-server replication so a deleted-from-one-server blob is still reachable. v2. |
| NIP-94 (Kind 1063) interop | Some clients publish file events separately from the carrier event. We don't emit or consume Kind 1063 in v1 — `imeta` on Kind 1 / 42 covers our use case. |

---

## 12. Five-minute mental model

If you forget everything else, remember this:

1. **Nostr carries text + references**. Bytes don't fit in events; they go elsewhere.
2. **Blossom is "elsewhere"** — an HTTP blob store keyed by sha256. Our backend runs one alongside the relay.
3. **`imeta` is the bridge** — a Nostr tag that says "this event references the blob at URL X with sha Y of type Z".
4. **Receivers see the metadata first, bytes only on demand.** Tap Download to fetch bytes. The blurhash or mime icon is the placeholder.
5. **Sha256 is identity.** The same blob in 10 notes = 1 upload + 1 cache entry on each receiver. GC counts references and only deletes when none remain (or the user pinned it).
6. **Layers are strict.** UI reads `note.attachments` — the data layer (`NoteAttachmentsEnricher`) put it there. The gateway parses `imeta` on inbound. Nobody crosses lanes.


1. What is UserServerListRepository and why it exists

  Plain words: it stores the answer to "which Blossom servers does this user use
  for their media?"

  Why it was needed:

  - Nostr is decentralized. Your notes live on relays, but the bytes of your
  photos/videos live on Blossom servers (Azure-backed HTTP blob stores). These
  are two different machines.
  - When someone else sees your note imeta tag, they only see the SHA-256 hash.
  They need to know where to download the bytes from. That "where" is your
  server list.
  - The standard way to announce this is a Kind 10063 event (BUD-03 / NIP-B7).
  It's just a list of ["server", "https://..."] tags signed by you.

  Why a whole repository for one URL?

  1. Cache locally — we don't want to re-fetch the Kind 10063 event every time
  we upload a photo. The single-row UserServerListModel in Isar is that cache.
  2. Single source of truth — the uploader, the downloader, and the Brahma
  composer all ask the same place: "what's my Blossom server?"
  3. Future-proof — today we hardcode our own backend, but the moment we add a
  second server (BUD-03 fan-out), no code outside this repo needs to change.
  4. Sync across devices — log in on device B, the Gateway receives your Kind
  10063, Kind10063UserServerListHandler calls reconcileFromEvent(), and device B
  now knows the same servers without re-uploading anything.

  The Last-Write-Wins check on lastSyncedCreatedAt is so that an old event
  arriving late doesn't overwrite a newer one.

  ---
  2. Media system — end-to-end flow

  A. UPLOAD (Brahma composer → published note with image)

  User taps "Attach Image" in Brahma
          │
          ▼
  image_picker → File on disk
          │
          ▼
  compose_media_sheet.dart
     - checks size, compresses if needed (ImageCompressor / VideoCompressor)
     - Windows skips compression (no native backend)
          │
          ▼
  BrahmaCreateBloc.AttachImageEvent
          │
          ▼
  UploadMediaUseCase
          │
          ▼
  MediaRepositoryImpl.uploadFromFile()
     1. crypto.sha256 → compute hash of the bytes
     2. ask UserServerListRepository.getServers()  ◄── 1st use of Kind 10063
          → returns ["https://dev.uniun.in:8080"]
     3. BlossomClient.head(server, sha256)
          → if already there: skip upload (deduped)
     4. flutter_blurhash.encode (in compute() isolate)
     5. BlossomClient.upload(server, bytes, mime, keys)
          ├── signs Kind 24242 auth event  ◄── Blossom auth kind
          │     tags: [["t","upload"],["x",sha256],["expiration",now+5min]]
          ├── PUT  https://server/upload
          │     Header: Authorization: Nostr <base64(eventJson)>
          │     Body : raw bytes
          └── relay's Khatru + blossom plugin stores it in Azure
     6. MediaCacheDataSource.write(sha256, ext, bytes)
          → writes to <appSupport>/media/<sha256>.<ext>
     7. isar.writeTxn → upsert MediaBlobModel (localPath set, blurhash set)
     8. First-ever upload → also publishes Kind 10063  ◄── 2nd use
          (so other devices learn your server)
          │
          ▼
  Brahma builds the Note event with an imeta tag:
     ["imeta",
       "url https://dev.uniun.in:8080/<sha256>.jpg",
       "m image/jpeg",
       "x <sha256>",
       "size 482133",
       "dim 1920x1080",
       "blurhash LKO2?U..."]
          │
          ▼
  EventQueueModel (rawPassthrough = true because imeta order matters)
          │
          ▼
  Gateway WebSocket → relay → other subscribers

  B. RECEIVE on another device (no download yet)

  Relay sends ["EVENT", {...kind:1, tags:[...,imeta...]}]
          │
          ▼
  kind1_note_handler.dart
     - parses the event into NoteModel
     - imeta_parser.dart walks imeta tags
          │
          ▼
  For each imeta:
     - upsert MediaBlobModel (sha256, mime, dim, blurhash, serverUrls)
     - localPath stays NULL  ← bytes not pulled yet
     - write NoteMediaRefModel(noteEventId, sha256)
          │
          ▼
  NoteCard renders
     - MediaAttachmentView sees blob with localPath==null
     - shows flutter_blurhash placeholder + "Download" button
     - Gallery does NOT show it (just-fixed rule: localPath==null hidden)

  C. DOWNLOAD (user taps the download button)

  User taps Download
          │
          ▼
  DownloadMediaUseCase
          │
          ▼
  MediaRepositoryImpl.downloadBySha(sha256)
     1. Read MediaBlobModel → pick serverUrls.first
          (note: _serverBase coerces wss:// → https://)
     2. BlossomClient.download(server, sha256)
          ├── signs Kind 24242 auth ["t","get"]  ◄── 3rd use of Blossom kind
          └── GET https://server/<sha256>
     3. verify sha256 of returned bytes (security)
     4. MediaCacheDataSource.write → file on disk
     5. isar.writeTxn → MediaBlobModel.localPath = path, downloadedAt = now
          │
          ▼
  NoteCard auto-rebuilds → shows real Image.file(...)
  Gallery now shows it (localPath != null)

  D. CROSS-DEVICE Kind 10063 sync

  Device A first upload → publishes Kind 10063 {["server", "..."]}
          │
          ▼ relay broadcasts
  Device B Gateway subscription picks it up
          │
          ▼
  kind10063_user_server_list_handler.dart
          │
          ▼
  UserServerListRepository.reconcileFromEvent()
     - LWW check on createdAt
     - writes server URLs to local UserServerListModel
          │
          ▼
  Device B can now upload to / download from the same servers

  ---
  Summary of the two special kinds

  Kind: 24242 (Blossom auth)
  Where signed: Inside BlossomClient per HTTP call
  Where used: Sent in Authorization: Nostr ... header for upload / get / delete
  /
    list
  Why: Proves to the Blossom server that you own this pubkey before it accepts
    the byte op. Expires in 5 min so a leaked header can't be reused.
  ────────────────────────────────────────
  Kind: 10063 (User server list)
  Where signed: UserServerListRepositoryImpl._publishServerList
  Where used: Published once on first upload + when server list changes;
  consumed
    by Kind10063UserServerListHandler on remote devices
  Why: So clients downloading your media know which Blossom server to hit.
    Without it, the imeta url is still there, but having the Kind 10063 makes a
    client robust to URL-mangling (it can fall back to <knownServer>/<sha256>).

