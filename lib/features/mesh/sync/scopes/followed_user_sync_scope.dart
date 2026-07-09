import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_user_model.dart';

import '../bodies/followed_user_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30505 FollowedUser scope. Addressable slot `d = pubkeyHex`.
class FollowedUserSyncScope extends MeshRecordSyncScope<FollowedUserModel> {
  FollowedUserSyncScope(super.isar, super.codec);

  @override
  String get name => 'followedUser';

  @override
  int get meshKind => MeshEventKinds.followedUser;

  @override
  Future<List<FollowedUserModel>> signedRows() =>
      isar.followedUserModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(FollowedUserModel row) => row.signedNostrEvent;

  @override
  Future<FollowedUserModel?> findExisting(MeshEventRecord record) => isar
      .followedUserModels
      .filter()
      .pubkeyHexEqualTo(record.dTag)
      .findFirst();

  @override
  FollowedUserModel? applyRecord(
    MeshEventRecord record,
    FollowedUserModel? existing,
  ) => FollowedUserBody.applyBody(
    record.content,
    pubkeyHex: record.dTag,
    existing: existing,
  );

  @override
  Future<void> putRow(FollowedUserModel row) =>
      isar.followedUserModels.put(row);

  @override
  void stampSigned(
    FollowedUserModel row,
    String signedJson,
    DateTime? removedAt,
  ) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
