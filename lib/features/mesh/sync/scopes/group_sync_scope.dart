import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';

import '../bodies/group_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30540 Group scope. Addressable slot `d = groupId`.
///
/// Mirrors NIP-28 public-group membership across devices on the same identity,
/// entirely over the mesh (no relay). Once a group row lands on the peer, the
/// Gateway's [GroupsSubscription] backfills the actual kind 42 messages from the
/// group's relays.
class GroupSyncScope extends MeshRecordSyncScope<GroupModel> {
  GroupSyncScope(super.isar, super.codec);

  @override
  String get name => 'group';

  @override
  int get meshKind => MeshEventKinds.group;

  @override
  Future<List<GroupModel>> signedRows() =>
      isar.groupModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(GroupModel row) => row.signedNostrEvent;

  @override
  Future<GroupModel?> findExisting(MeshEventRecord record) =>
      isar.groupModels.where().groupIdEqualTo(record.dTag).findFirst();

  @override
  GroupModel? applyRecord(MeshEventRecord record, GroupModel? existing) =>
      GroupBody.applyBody(
        record.content,
        groupId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(GroupModel row) => isar.groupModels.put(row);

  @override
  void stampSigned(GroupModel row, String signedJson, DateTime? removedAt) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
