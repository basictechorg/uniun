import 'package:uniun/data/models/private_group_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30541 PrivateGroup mesh event.
///
/// Carries the NIP-29 private-group metadata so a second device on the same
/// identity can materialize the group in its list. MLS key material is NOT a
/// meaningful cross-device value (MLS state is per-device), so [mlsGroupId] is
/// carried only as informational fidelity and never clobbers a peer's own
/// binding on apply. Addressable slot `d = groupId`.
class PrivateGroupBody {
  const PrivateGroupBody._();

  static Map<String, dynamic> forActive(PrivateGroupModel m) =>
      _base(m, state: MeshRecordState.active);

  static Map<String, dynamic> forRemoved(PrivateGroupModel m) =>
      _base(m, state: MeshRecordState.removed);

  static Map<String, dynamic> _base(
    PrivateGroupModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'mlsGroupId': m.mlsGroupId,
      'name': m.name,
      'description': m.description,
      'relays': m.relays,
      'adminPubkey': m.adminPubkey,
    };
  }

  /// Reconstruct a [PrivateGroupModel] from a decoded body. [groupId] comes
  /// from the event's `d` tag. Reuses [existing] so the row's Isar id — and its
  /// own MLS binding — are preserved.
  static PrivateGroupModel applyBody(
    Map<String, dynamic> body, {
    required String groupId,
    PrivateGroupModel? existing,
  }) {
    final row = existing ?? PrivateGroupModel();
    row.groupId = groupId;
    // Never clobber a non-empty local MLS binding: this device may have its own
    // Welcome-derived MLS group that the peer's snapshot must not overwrite.
    final incomingMls = _asString(body['mlsGroupId']);
    row.mlsGroupId = (existing != null && existing.mlsGroupId.isNotEmpty)
        ? existing.mlsGroupId
        : incomingMls;
    row.name = _asString(body['name']);
    row.description = _asString(body['description']);
    row.relays = <String>[
      if (body['relays'] is List)
        for (final r in body['relays'] as List)
          if (r is String && r.isNotEmpty) r,
    ];
    row.adminPubkey = _asString(body['adminPubkey']);
    return row;
  }

  static String _asString(Object? v) => v is String ? v : '';
}
