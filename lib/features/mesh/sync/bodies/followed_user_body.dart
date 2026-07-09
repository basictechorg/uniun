import 'package:uniun/data/models/followed_user_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30505 FollowedUser mesh event.
class FollowedUserBody {
  const FollowedUserBody._();

  static Map<String, dynamic> forActive(FollowedUserModel m) =>
      _base(m, state: MeshRecordState.active);

  static Map<String, dynamic> forRemoved(FollowedUserModel m) =>
      _base(m, state: MeshRecordState.removed);

  static Map<String, dynamic> _base(
    FollowedUserModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'relayHint': m.relayHint,
      'petname': m.petname,
      'followedAt': m.followedAt.millisecondsSinceEpoch,
      'lastKind3CreatedAt': m.lastKind3CreatedAt?.millisecondsSinceEpoch,
    };
  }

  static FollowedUserModel applyBody(
    Map<String, dynamic> body, {
    required String pubkeyHex,
    FollowedUserModel? existing,
  }) {
    final row = existing ?? FollowedUserModel();
    row.pubkeyHex = pubkeyHex;
    row.relayHint = _asNullableString(body['relayHint']);
    row.petname = _asNullableString(body['petname']);
    row.followedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['followedAt']),
    );
    final lastKind3CreatedAt = body['lastKind3CreatedAt'];
    row.lastKind3CreatedAt = lastKind3CreatedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(_asInt(lastKind3CreatedAt));
    return row;
  }

  static String? _asNullableString(Object? v) => v is String ? v : null;
  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
}
