import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/private_group_model.dart';

import '../bodies/private_group_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30541 PrivateGroup scope. Addressable slot `d = groupId`.
///
/// Mirrors NIP-29 private-group membership across devices on the same identity,
/// entirely over the mesh (no relay). The decrypted message bodies still ride
/// the [PrivateNoteSyncScope] (kind 30530); this scope only carries the group's
/// metadata so it appears in the peer's group list.
class PrivateGroupSyncScope extends MeshRecordSyncScope<PrivateGroupModel> {
  PrivateGroupSyncScope(super.isar, super.codec);

  @override
  String get name => 'privateGroup';

  @override
  int get meshKind => MeshEventKinds.privateGroup;

  @override
  Future<List<PrivateGroupModel>> signedRows() =>
      isar.privateGroupModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(PrivateGroupModel row) => row.signedNostrEvent;

  @override
  Future<PrivateGroupModel?> findExisting(MeshEventRecord record) =>
      isar.privateGroupModels.where().groupIdEqualTo(record.dTag).findFirst();

  @override
  PrivateGroupModel? applyRecord(
    MeshEventRecord record,
    PrivateGroupModel? existing,
  ) =>
      PrivateGroupBody.applyBody(
        record.content,
        groupId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(PrivateGroupModel row) =>
      isar.privateGroupModels.put(row);

  @override
  void stampSigned(
    PrivateGroupModel row,
    String signedJson,
    DateTime? removedAt,
  ) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
