import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/blocked_user_model.dart';

import '../bodies/blocked_user_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30502 BlockedUser scope. Addressable slot `d = pubkeyHex`. All shared
/// machinery lives in [MeshRecordSyncScope].
class BlockedUserSyncScope extends MeshRecordSyncScope<BlockedUserModel> {
  BlockedUserSyncScope(super.isar, super.codec);

  @override
  String get name => 'blockedUser';

  @override
  int get meshKind => MeshEventKinds.blockedUser;

  @override
  Future<List<BlockedUserModel>> signedRows() =>
      isar.blockedUserModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(BlockedUserModel row) => row.signedNostrEvent;

  @override
  Future<BlockedUserModel?> findExisting(MeshEventRecord record) =>
      isar.blockedUserModels.filter().pubkeyHexEqualTo(record.dTag).findFirst();

  @override
  BlockedUserModel? applyRecord(
    MeshEventRecord record,
    BlockedUserModel? existing,
  ) =>
      BlockedUserBody.applyBody(
        record.content,
        pubkeyHex: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(BlockedUserModel row) =>
      isar.blockedUserModels.put(row);

  @override
  void stampSigned(
    BlockedUserModel row,
    String signedJson,
    DateTime? removedAt,
  ) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
