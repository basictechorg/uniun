import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30530 `privateNote` mesh event.
///
/// This is the JSON we NIP-44-self-encrypt into `event.content` for the
/// unsigned note surfaces — DM (kind 14/15) and private group (kind 9023).
/// Their original wire form can't be stateless-verified by a peer (deniable
/// NIP-17 rumors carry no signature; MLS ciphertext needs per-device group
/// state), so we ship the already-decrypted plaintext and the receiver rebuilds
/// the [NoteModel] directly — no re-decrypt, no MLS state needed.
///
/// The body is a superset of everything the receiver needs to materialize the
/// row without a follow-up question. The DM FK [NoteModel.conversationId] is a
/// deterministic `fastHash(otherPubkey)`, identical on every device, so it
/// transfers verbatim; the matching `DmConversation` row reconciles via its own
/// Kind-30503 scope.
class PrivateNoteBody {
  const PrivateNoteBody._();

  /// Builds the plaintext body for an active private note.
  static Map<String, dynamic> forActive(NoteModel m) =>
      _base(m, state: MeshRecordState.active);

  static Map<String, dynamic> _base(
    NoteModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'kind': m.kind,
      'sig': m.sig,
      'pubkey': m.authorPubkey,
      'content': m.content,
      if (m.subject != null) 'subject': m.subject,
      'type': m.type.name,
      'eTagRefs': m.eTagRefs,
      if (m.rootEventId != null) 'rootEventId': m.rootEventId,
      if (m.replyToEventId != null) 'replyToEventId': m.replyToEventId,
      'pTagRefs': m.pTagRefs,
      'tTags': m.tTags,
      'created': m.created.millisecondsSinceEpoch,
      if (m.conversationId != null) 'conversationId': m.conversationId,
      if (m.privateGroupId != null) 'privateGroupId': m.privateGroupId,
      if (m.groupId != null) 'groupId': m.groupId,
      if (m.embeddedNoteJson != null) 'embeddedNoteJson': m.embeddedNoteJson,
      'attachments': [
        for (final a in m.attachments) _encodeAttachment(a),
      ],
    };
  }

  /// Applies a decoded body onto a [NoteModel] (creates one if [existing] is
  /// null). LWW dispatch (§5a) is the caller's responsibility. The caller
  /// stamps [NoteModel.privateMeshEventJson] to reflect the winning event.
  static NoteModel applyBody(
    Map<String, dynamic> body, {
    required String eventId,
    NoteModel? existing,
  }) {
    final kind = _asInt(body['kind']);
    final model = NoteModel(
      eventId: eventId,
      sig: _asString(body['sig']),
      authorPubkey: _asString(body['pubkey']),
      content: _asString(body['content']),
      subject: body['subject'] as String?,
      kind: kind == 0 ? kDmTextKind : kind,
      conversationId: (body['conversationId'] as num?)?.toInt(),
      privateGroupId: body['privateGroupId'] as String?,
      groupId: body['groupId'] as String?,
      type: _parseNoteType(body['type']),
      eTagRefs: _asStringList(body['eTagRefs']),
      rootEventId: body['rootEventId'] as String?,
      replyToEventId: body['replyToEventId'] as String?,
      pTagRefs: _asStringList(body['pTagRefs']),
      tTags: _asStringList(body['tTags']),
      created: DateTime.fromMillisecondsSinceEpoch(_asInt(body['created'])),
      embeddedNoteJson: body['embeddedNoteJson'] as String?,
      attachments: <MediaAttachment>[
        for (final a in _asMapList(body['attachments'])) _decodeAttachment(a),
      ],
    );
    // Preserve the local autoincrement id so the put updates in place.
    if (existing != null) model.id = existing.id;
    return model;
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
