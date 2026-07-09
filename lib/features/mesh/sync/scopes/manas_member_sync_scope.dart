import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';

import '../bodies/manas_member_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30511 Manas membership-edge scope. One event per `(manasId, noteId)`
/// pair; the addressable slot `d = "$manasId:$noteId"` is decoded via
/// [ManasMemberBody.parseDTag]. A malformed `d` tag drops the record (return
/// null) rather than throwing. All other machinery lives in
/// [MeshRecordSyncScope].
class ManasMemberSyncScope extends MeshRecordSyncScope<ManasNoteLinkModel> {
  ManasMemberSyncScope(super.isar, super.codec);

  @override
  String get name => 'manasMember';

  @override
  int get meshKind => MeshEventKinds.manasMember;

  @override
  Future<List<ManasNoteLinkModel>> signedRows() =>
      isar.manasNoteLinkModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(ManasNoteLinkModel row) => row.signedNostrEvent;

  @override
  Future<ManasNoteLinkModel?> findExisting(MeshEventRecord record) {
    final parsed = ManasMemberBody.parseDTag(record.dTag);
    if (parsed == null) return Future.value(null);
    return isar.manasNoteLinkModels
        .filter()
        .manasIdEqualTo(parsed.manasId)
        .noteIdEqualTo(parsed.noteId)
        .findFirst();
  }

  @override
  ManasNoteLinkModel? applyRecord(
    MeshEventRecord record,
    ManasNoteLinkModel? existing,
  ) {
    final parsed = ManasMemberBody.parseDTag(record.dTag);
    if (parsed == null) {
      debugPrint('MESH/SYNC: manasMember malformed d tag: ${record.dTag}');
      return null;
    }
    return ManasMemberBody.applyBody(
      record.content,
      manasId: parsed.manasId,
      noteId: parsed.noteId,
      existing: existing,
    );
  }

  @override
  Future<void> putRow(ManasNoteLinkModel row) =>
      isar.manasNoteLinkModels.put(row);

  @override
  void stampSigned(
    ManasNoteLinkModel row,
    String signedJson,
    DateTime? removedAt,
  ) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
