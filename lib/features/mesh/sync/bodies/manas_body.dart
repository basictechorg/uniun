import 'package:uniun/data/models/manas_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30510 Manas definition event (plan §5).
///
/// The `d` tag is the Manas's `manasId`, so create / rename / delete all
/// address the same addressable slot. LWW on `created_at` collapses edit
/// history to a single winning definition per device.
///
/// Membership does NOT ride on this event — it is a separate Kind (30511)
/// per `(manas, note)` edge (see [ManasMemberBody]).
class ManasBody {
  const ManasBody._();

  static Map<String, dynamic> forActive(ManasModel m) => _base(
        m,
        state: MeshRecordState.active,
      );

  static Map<String, dynamic> forRemoved(ManasModel m) => _base(
        m,
        state: MeshRecordState.removed,
      );

  static Map<String, dynamic> _base(
    ManasModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'name': m.name,
      'description': m.description,
      'iconName': m.iconName,
      'createdAt': m.createdAt.millisecondsSinceEpoch,
      'updatedAt': m.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Applies a decoded body onto a [ManasModel] (creates one if [existing]
  /// is null). Caller sets `signedNostrEvent` + `removedAt` per the winning
  /// event's state.
  static ManasModel applyBody(
    Map<String, dynamic> body, {
    required String manasId,
    ManasModel? existing,
  }) {
    final row = existing ?? ManasModel();
    row.manasId = manasId;
    row.name = (body['name'] as String?) ?? '';
    row.description = body['description'] as String?;
    row.iconName = body['iconName'] as String?;
    row.createdAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['createdAt']),
    );
    row.updatedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(body['updatedAt']),
    );
    return row;
  }

  static int _asInt(Object? v) => (v is num) ? v.toInt() : 0;
}
