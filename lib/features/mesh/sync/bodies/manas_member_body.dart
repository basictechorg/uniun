import 'package:uniun/data/models/manas_note_link_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30511 Manas membership edge event
/// (plan §5, Phase 4). One event per `(manasId, noteId)` pair — adds and
/// removes each publish a fresh event on the same `d = "$manasId:$noteId"`
/// slot, so concurrent add-clobber can't happen and there is no re-sign
/// cost when Manas membership grows.
///
/// The `d` tag encodes both ids: [buildDTag] concatenates with a `':'`
/// separator. `manasId` and `noteId` are opaque strings on our side — the
/// separator is safe because `manasId` is our own UUID (no colon) and
/// `noteId` is a hex event id (no colon).
class ManasMemberBody {
  const ManasMemberBody._();

  /// Constructs the addressable slot key for one membership edge.
  static String buildDTag(String manasId, String noteId) =>
      '$manasId:$noteId';

  /// Splits a `d` tag back into `(manasId, noteId)`. Returns `null` if the
  /// tag is malformed (missing separator or empty parts).
  static ({String manasId, String noteId})? parseDTag(String dTag) {
    final idx = dTag.indexOf(':');
    if (idx <= 0 || idx == dTag.length - 1) return null;
    return (
      manasId: dTag.substring(0, idx),
      noteId: dTag.substring(idx + 1),
    );
  }

  static Map<String, dynamic> forActive(ManasNoteLinkModel m) => _base(
        m,
        state: MeshRecordState.active,
      );

  static Map<String, dynamic> forRemoved(ManasNoteLinkModel m) => _base(
        m,
        state: MeshRecordState.removed,
      );

  static Map<String, dynamic> _base(
    ManasNoteLinkModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'addedAt': m.addedAt.millisecondsSinceEpoch,
    };
  }

  /// Applies a decoded body onto a [ManasNoteLinkModel] (creates one if
  /// [existing] is null). Caller sets `signedNostrEvent` + `removedAt` per
  /// the winning event's state.
  static ManasNoteLinkModel applyBody(
    Map<String, dynamic> body, {
    required String manasId,
    required String noteId,
    ManasNoteLinkModel? existing,
  }) {
    final row = existing ?? ManasNoteLinkModel();
    row.manasId = manasId;
    row.noteId = noteId;
    row.addedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['addedAt']),
    );
    return row;
  }

  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
}
