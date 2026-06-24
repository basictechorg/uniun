import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

part 'event_queue_model.g.dart';

/// Durable outbound event queue. Each row represents one signed Nostr event
/// that needs to be published to one or more relays.
///
/// [id] is the Isar autoincrement integer — used as the ordered cursor by
/// every [WebSocketService] so each connection tracks its own send position
/// independently via [WebSocketService._lastSentQueueId].
///
/// An entry is eligible for dequeue when:
///   sentCount >= number of currently connected write relays
///   AND enqueuedAt < now - 30 minutes
@Collection(ignore: {'copyWith'})
@Name('EventQueue')
class EventQueueModel {
  Id id = Isar.autoIncrement;

  /// Nostr event ID (SHA256 hex) — unique per event.
  @Index(unique: true)
  late String eventId;

  late String authorPubkey;
  late String sig;
  late String content;
  late int kind;
  late List<String> eTagRefs;
  String? rootEventId;
  String? replyToEventId;
  late List<String> pTagRefs;
  late List<String> tTags;
  late DateTime created;

  /// Embed-by-value share snapshot — re-emitted as the `embeddedNoteJson` tag
  /// so the broadcast event hashes back to [eventId] (sig validation depends on
  /// it). See [EmbeddedNoteCodec].
  String? embeddedNoteJson;

  /// NIP-37 draft kind hint → `["k","1"]`. Drafts only; no quote pointer exists
  /// anymore (kept the name to avoid churn across the enqueue interface).
  int? quoteKind;

  /// NIP-29 private channel group id → `["h", hTag]`.
  String? hTag;

  /// NIP-37 draft id → `["d", dTag]`.
  String? dTag;

  /// NIP-37 draft expiration timestamp (seconds) → `["expiration", ...]`.
  int? expirationSec;

  /// BUD-03 user server list → one `["server", url]` per entry.
  List<String> serverTags = const [];

  /// NIP-92 media attachments → one `["imeta", ...]` per entry.
  List<MediaAttachment> imeta = const [];

  /// NIP-56 report type (one of [ReportType] names: `nudity`/`malware`/etc).
  ///
  /// When non-null the canonical serializer emits report-shaped tags:
  ///   `["e", id, "", reportType]` instead of NIP-10 root/reply/mention markers
  ///   `["p", pubkey, reportType]` instead of bare `["p", pubkey]`
  ///
  /// Reports never carry NIP-10 threading semantics, so `rootEventId` /
  /// `replyToEventId` must be null when `reportType` is set. The publisher
  /// (`ReportRepositoryImpl`) signs in this exact shape.
  String? reportType;

  /// Number of write-relay connections that have received ["OK", id, true].
  /// Incremented atomically by each WebSocketService on successful ACK.
  late int sentCount = 0;

  /// When this event was enqueued. Used for the 30-minute dequeue gate.
  late DateTime enqueuedAt;
}

/// Tag reconstruction order — every publisher MUST sign in this order, or
/// the broadcast event will re-serialize to a different SHA-256 than the
/// signed [eventId] and the relay will reject the signature.
///
///   1. e root  (NIP-10)
///   2. e reply (NIP-10)
///   3. e mention… (remaining [eTagRefs])
///   4. p…
///   5. t…
///   6. h          (NIP-29 private channel)
///   7. d          (NIP-37 draft id)
///   8. k          (NIP-37 draft kind hint ["k","1"]; drafts only)
///   9. embeddedNoteJson (UNIUN embed-by-value share snapshot)
///  10. expiration (NIP-37 expiry)
///  11. server…    (BUD-03)
///  12. imeta…     (NIP-92)
extension EventQueueModelExtension on EventQueueModel {
  /// Populates this queue row from a data-layer [NoteModel].
  EventQueueModel populateFromNoteModel(NoteModel note) {
    eventId = note.eventId;
    authorPubkey = note.authorPubkey;
    sig = note.sig;
    content = note.content;
    kind = 1;
    eTagRefs = List<String>.from(note.eTagRefs);
    rootEventId = note.rootEventId;
    replyToEventId = note.replyToEventId;
    pTagRefs = List<String>.from(note.pTagRefs);
    tTags = List<String>.from(note.tTags);
    created = note.created;
    embeddedNoteJson = note.embeddedNoteJson;
    imeta = List<MediaAttachment>.from(note.attachments);
    sentCount = 0;
    enqueuedAt = DateTime.now();
    return this;
  }

  /// Populates this queue row from a domain-layer [NoteEntity].
  ///
  /// NoteEntity does not carry root/reply threading markers, so those remain
  /// null and all eTagRefs are emitted as mention tags.
  EventQueueModel populateFromNoteEntity(NoteEntity note) {
    eventId = note.id;
    authorPubkey = note.authorPubkey;
    sig = note.sig;
    content = note.content;
    kind = 1;
    eTagRefs = List<String>.from(note.eTagRefs);
    rootEventId = null;
    replyToEventId = null;
    pTagRefs = List<String>.from(note.pTagRefs);
    tTags = List<String>.from(note.tTags);
    created = note.created;
    embeddedNoteJson = note.embeddedNoteJson;
    imeta = note.attachments
        .map((b) => MediaAttachment()
          ..sha256 = b.sha256
          ..mime = b.mime
          ..sizeBytes = b.sizeBytes
          ..url = b.serverUrls.isNotEmpty ? b.serverUrls.first : null
          ..width = b.dim?.width
          ..height = b.dim?.height
          ..blurhash = b.blurhash
          ..filename = b.filename)
        .toList();
    sentCount = 0;
    enqueuedAt = DateTime.now();
    return this;
  }

  /// Relay wire message: `["EVENT", {signed-event-json}]`.
  /// Tag order MUST match the canonical order documented above; signing
  /// publishers must follow the same order.
  String toSerializedRelayMessage() {
    // NIP-56 report shape — flat e/p tags with report type as the trailing
    // positional entry. Pre-empts the NIP-10 marker branch entirely.
    final isReport = reportType != null;
    final tags = <List<String>>[
      if (isReport)
        for (final ref in eTagRefs) ['e', ref, '', reportType!]
      else ...[
        if (rootEventId != null) ['e', rootEventId!, '', 'root'],
        if (replyToEventId != null) ['e', replyToEventId!, '', 'reply'],
        for (final ref in eTagRefs)
          if (ref != rootEventId && ref != replyToEventId)
            ['e', ref, '', 'mention'],
      ],
      for (final p in pTagRefs)
        if (isReport) ['p', p, reportType!] else ['p', p],
      for (final t in tTags) ['t', t],
      if (hTag != null) ['h', hTag!],
      if (dTag != null) ['d', dTag!],
      if (quoteKind != null) ['k', quoteKind!.toString()],
      if (embeddedNoteJson != null)
        [EmbeddedNoteCodec.tagName, embeddedNoteJson!],
      if (expirationSec != null) ['expiration', expirationSec!.toString()],
      for (final url in serverTags) ['server', url],
      for (final a in imeta) _imetaTag(a),
    ];

    return jsonEncode([
      'EVENT',
      <String, dynamic>{
        'id': eventId,
        'pubkey': authorPubkey,
        'created_at': created.millisecondsSinceEpoch ~/ 1000,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      },
    ]);
  }

  static List<String> _imetaTag(MediaAttachment a) {
    return [
      'imeta',
      if (a.url != null) 'url ${a.url}',
      'm ${a.mime}',
      'x ${a.sha256}',
      if (a.sizeBytes > 0) 'size ${a.sizeBytes}',
      if (a.width != null && a.height != null) 'dim ${a.width}x${a.height}',
      if (a.blurhash != null) 'blurhash ${a.blurhash}',
      if (a.filename != null && a.filename!.isNotEmpty) 'name ${a.filename}',
    ];
  }
}
