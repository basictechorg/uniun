import 'package:uniun/data/models/followed_note_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30501 FollowedNote mesh event (plan §5).
///
/// The `d` tag is the followed note's `eventId`, so follow/unfollow both
/// address the same addressable slot — LWW on `created_at` collapses the
/// toggle history to a single winning state per device.
///
/// `newReferenceCount` is intentionally NOT synced. Unread counters are
/// derived at read-time from `NoteRelationModel × UnreadNoteModel` (see
/// `FollowedNoteRepositoryImpl._deriveUnreadRefCount`), so re-materializing
/// them cross-device would double-count. Each device tracks its own reads.
class FollowedNoteBody {
  const FollowedNoteBody._();

  static Map<String, dynamic> forActive(FollowedNoteModel m) => _base(
        m,
        state: MeshRecordState.active,
      );

  /// Removed variant — same fields; the tombstone stays authoritative for
  /// the row's shape when a peer only ever sees the removal.
  static Map<String, dynamic> forRemoved(FollowedNoteModel m) => _base(
        m,
        state: MeshRecordState.removed,
      );

  static Map<String, dynamic> _base(
    FollowedNoteModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'followedAt': m.followedAt.millisecondsSinceEpoch,
      'contentPreview': m.contentPreview,
    };
  }

  /// Applies a decoded body onto a [FollowedNoteModel] (creates one if
  /// [existing] is null). Caller sets `signedNostrEvent` + `removedAt` per
  /// the winning event's state.
  static FollowedNoteModel applyBody(
    Map<String, dynamic> body, {
    required String eventId,
    FollowedNoteModel? existing,
  }) {
    final row = existing ?? FollowedNoteModel();
    row.eventId = eventId;
    row.contentPreview = _asString(body['contentPreview']);
    row.followedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['followedAt']),
    );
    return row;
  }

  static String _asString(Object? v) => v is String ? v : '';
  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
}
