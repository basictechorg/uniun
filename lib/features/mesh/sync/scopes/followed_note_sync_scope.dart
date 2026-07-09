import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_note_model.dart';

import '../bodies/followed_note_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30501 FollowedNote scope. Addressable slot `d = eventId` (the followed
/// note). All shared machinery lives in [MeshRecordSyncScope].
class FollowedNoteSyncScope extends MeshRecordSyncScope<FollowedNoteModel> {
  FollowedNoteSyncScope(super.isar, super.codec);

  @override
  String get name => 'followedNote';

  @override
  int get meshKind => MeshEventKinds.followedNote;

  @override
  Future<List<FollowedNoteModel>> signedRows() =>
      isar.followedNoteModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(FollowedNoteModel row) => row.signedNostrEvent;

  @override
  Future<FollowedNoteModel?> findExisting(MeshEventRecord record) =>
      isar.followedNoteModels.filter().eventIdEqualTo(record.dTag).findFirst();

  @override
  FollowedNoteModel? applyRecord(
    MeshEventRecord record,
    FollowedNoteModel? existing,
  ) =>
      FollowedNoteBody.applyBody(
        record.content,
        eventId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(FollowedNoteModel row) =>
      isar.followedNoteModels.put(row);

  @override
  void stampSigned(
    FollowedNoteModel row,
    String signedJson,
    DateTime? removedAt,
  ) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
