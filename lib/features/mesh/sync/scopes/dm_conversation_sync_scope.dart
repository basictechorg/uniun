import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';

import '../bodies/dm_conversation_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30503 DmConversation scope. Addressable slot `d = otherPubkey`. All
/// shared machinery lives in [MeshRecordSyncScope].
class DmConversationSyncScope extends MeshRecordSyncScope<DmConversationModel> {
  DmConversationSyncScope(super.isar, super.codec);

  @override
  String get name => 'dmConversation';

  @override
  int get meshKind => MeshEventKinds.dmConversation;

  @override
  Future<List<DmConversationModel>> signedRows() =>
      isar.dmConversationModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(DmConversationModel row) => row.signedNostrEvent;

  @override
  Future<DmConversationModel?> findExisting(MeshEventRecord record) => isar
      .dmConversationModels
      .filter()
      .otherPubkeyEqualTo(record.dTag)
      .findFirst();

  @override
  DmConversationModel? applyRecord(
    MeshEventRecord record,
    DmConversationModel? existing,
  ) =>
      DmConversationBody.applyBody(
        record.content,
        otherPubkey: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(DmConversationModel row) =>
      isar.dmConversationModels.put(row);

  @override
  void stampSigned(
    DmConversationModel row,
    String signedJson,
    DateTime? removedAt,
  ) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
