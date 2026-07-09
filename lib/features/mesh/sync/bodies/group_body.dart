import 'package:uniun/data/models/group_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30540 Group mesh event.
///
/// Carries the full NIP-28 group metadata snapshot so a second device on the
/// same identity can materialize the group locally without a relay round-trip.
/// Addressable slot `d = groupId`.
class GroupBody {
  const GroupBody._();

  static Map<String, dynamic> forActive(GroupModel m) =>
      _base(m, state: MeshRecordState.active);

  static Map<String, dynamic> forRemoved(GroupModel m) =>
      _base(m, state: MeshRecordState.removed);

  static Map<String, dynamic> _base(
    GroupModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'creatorPubKey': m.creatorPubKey,
      'name': m.name,
      'about': m.about,
      'picture': m.picture,
      'relays': m.relays,
      'createdAt': m.createdAt,
      'updatedAt': m.updatedAt,
      'lastMetaEvent': m.lastMetaEvent,
    };
  }

  /// Reconstruct a [GroupModel] from a decoded body. [groupId] comes from the
  /// event's `d` tag. Reuses [existing] so the row's Isar id is preserved.
  static GroupModel applyBody(
    Map<String, dynamic> body, {
    required String groupId,
    GroupModel? existing,
  }) {
    final row = existing ?? GroupModel();
    row.groupId = groupId;
    row.creatorPubKey = _asString(body['creatorPubKey']);
    row.name = _asString(body['name']);
    row.about = _asString(body['about']);
    row.picture = _asString(body['picture']);
    row.relays = <String>[
      if (body['relays'] is List)
        for (final r in body['relays'] as List)
          if (r is String && r.isNotEmpty) r,
    ];
    row.createdAt = _asInt(body['createdAt']);
    row.updatedAt = _asInt(body['updatedAt']);
    row.lastMetaEvent = _asNullableString(body['lastMetaEvent']);
    return row;
  }

  static String _asString(Object? v) => v is String ? v : '';
  static String? _asNullableString(Object? v) => v is String ? v : null;
  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
}
