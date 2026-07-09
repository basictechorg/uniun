import 'package:uniun/data/models/blocked_user_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30502 BlockedUser mesh event (plan §5).
///
/// The `d` tag is the blocked user's `pubkeyHex`, so block/unblock both
/// address the same addressable slot. LWW on `created_at` collapses toggle
/// history to a single winning state per device.
class BlockedUserBody {
  const BlockedUserBody._();

  static Map<String, dynamic> forActive(BlockedUserModel m) => _base(
        m,
        state: MeshRecordState.active,
      );

  static Map<String, dynamic> forRemoved(BlockedUserModel m) => _base(
        m,
        state: MeshRecordState.removed,
      );

  static Map<String, dynamic> _base(
    BlockedUserModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'blockedAt': m.blockedAt.millisecondsSinceEpoch,
    };
  }

  /// Applies a decoded body onto a [BlockedUserModel] (creates one if
  /// [existing] is null). Caller sets `signedNostrEvent` + `removedAt` per
  /// the winning event's state.
  static BlockedUserModel applyBody(
    Map<String, dynamic> body, {
    required String pubkeyHex,
    BlockedUserModel? existing,
  }) {
    final row = existing ?? BlockedUserModel();
    row.pubkeyHex = pubkeyHex;
    row.blockedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['blockedAt']),
    );
    return row;
  }

  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
}
