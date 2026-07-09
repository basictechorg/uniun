import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/saved_note_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30500 SavedNote mesh event (plan §5).
///
/// This is the JSON we NIP-44-self-encrypt into `event.content`. It is
/// deliberately a superset of everything the receiver needs to rebuild a
/// [SavedNoteModel] — the mesh peer must be able to materialize the row
/// without asking the sender any follow-up questions.
///
/// The `note` field is a shallow embed of the original NoteEntity that was
/// saved: sig + author + content + threading refs + timestamp + attachments.
/// It is NOT a full [NoteEntity] `toJson()` (that carries UI-derived counts).
class SavedNoteBody {
  const SavedNoteBody._();

  /// Builds the plaintext body for a saved-active event.
  static Map<String, dynamic> forActive(SavedNoteModel m) => _base(
        m,
        state: MeshRecordState.active,
      );

  /// Builds the plaintext body for a saved-removed (undo) event.
  ///
  /// Same structural fields as [forActive] so a peer that only ever sees the
  /// removal (never the active event) can still populate every column — the
  /// tombstone is authoritative for the row's shape.
  static Map<String, dynamic> forRemoved(SavedNoteModel m) => _base(
        m,
        state: MeshRecordState.removed,
      );

  static Map<String, dynamic> _base(
    SavedNoteModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'savedAt': m.savedAt.millisecondsSinceEpoch,
      if (m.sourceGroupId != null) 'sourceGroupId': m.sourceGroupId,
      if (m.sourcePrivateGroupId != null)
        'sourcePrivateGroupId': m.sourcePrivateGroupId,
      if (m.embeddedNoteJson != null) 'embeddedNoteJson': m.embeddedNoteJson,
      'note': <String, dynamic>{
        'id': m.eventId,
        'sig': m.sig,
        'pubkey': m.authorPubkey,
        'content': m.content,
        'type': m.type.name,
        'eTagRefs': m.eTagRefs,
        'rootEventId': m.rootEventId,
        'replyToEventId': m.replyToEventId,
        'pTagRefs': m.pTagRefs,
        'tTags': m.tTags,
        'created': m.created.millisecondsSinceEpoch,
        'attachments': [
          for (final a in m.attachments) _encodeAttachment(a),
        ],
      },
    };
  }

  /// Applies a decoded body onto a [SavedNoteModel] instance (creates one if
  /// [existing] is null). Used by [SavedNoteSyncScope.upsertSigned] and by
  /// the Phase-0a migration pass on receive.
  ///
  /// LWW dispatch (§5a) is the caller's responsibility — this only maps the
  /// body onto the row. The caller sets [SavedNoteModel.signedNostrEvent] and
  /// [SavedNoteModel.removedAt] to reflect the winning event.
  static SavedNoteModel applyBody(
    Map<String, dynamic> body, {
    required String eventId,
    SavedNoteModel? existing,
  }) {
    final note = body['note'];
    if (note is! Map<String, dynamic>) {
      throw FormatException('SavedNote body missing note: $body');
    }
    final row = existing ?? SavedNoteModel();
    row.eventId = eventId;
    row.sig = _asString(note['sig']);
    row.authorPubkey = _asString(note['pubkey']);
    row.content = _asString(note['content']);
    row.type = _parseNoteType(note['type']);
    row.eTagRefs = _asStringList(note['eTagRefs']);
    row.rootEventId = note['rootEventId'] as String?;
    row.replyToEventId = note['replyToEventId'] as String?;
    row.pTagRefs = _asStringList(note['pTagRefs']);
    row.tTags = _asStringList(note['tTags']);
    row.created = DateTime.fromMillisecondsSinceEpoch(
      _asInt(note['created']),
    );
    row.savedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['savedAt']),
    );
    row.sourceGroupId = body['sourceGroupId'] as String?;
    row.sourcePrivateGroupId = body['sourcePrivateGroupId'] as String?;
    row.embeddedNoteJson = body['embeddedNoteJson'] as String?;
    row.attachments = <MediaAttachment>[
      for (final a in _asMapList(note['attachments'])) _decodeAttachment(a),
    ];
    return row;
  }

  static Map<String, dynamic> _encodeAttachment(MediaAttachment a) => {
        'sha256': a.sha256,
        'mime': a.mime,
        'sizeBytes': a.sizeBytes,
        if (a.url != null) 'url': a.url,
        if (a.width != null) 'width': a.width,
        if (a.height != null) 'height': a.height,
        if (a.blurhash != null) 'blurhash': a.blurhash,
        if (a.filename != null) 'filename': a.filename,
      };

  static MediaAttachment _decodeAttachment(Map<String, dynamic> j) =>
      MediaAttachment()
        ..sha256 = _asString(j['sha256'])
        ..mime = _asString(j['mime'])
        ..sizeBytes = (j['sizeBytes'] as num?)?.toInt() ?? 0
        ..url = j['url'] as String?
        ..width = (j['width'] as num?)?.toInt()
        ..height = (j['height'] as num?)?.toInt()
        ..blurhash = j['blurhash'] as String?
        ..filename = j['filename'] as String?;

  static String _asString(Object? v) => v is String ? v : '';
  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
  static List<String> _asStringList(Object? v) =>
      v is List ? v.whereType<String>().toList() : const <String>[];
  static List<Map<String, dynamic>> _asMapList(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map<String, dynamic>) e,
        ]
      : const <Map<String, dynamic>>[];

  static NoteType _parseNoteType(Object? v) {
    if (v is String) {
      for (final t in NoteType.values) {
        if (t.name == v) return t;
      }
    }
    return NoteType.text;
  }
}
