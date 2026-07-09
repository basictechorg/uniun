import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/manas_model.dart';

import '../bodies/manas_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30510 Manas definition scope. Addressable slot `d = manasId`. All
/// shared machinery lives in [MeshRecordSyncScope]. Membership edges ride on
/// the separate [ManasMemberSyncScope] (Kind 30511).
class ManasSyncScope extends MeshRecordSyncScope<ManasModel> {
  ManasSyncScope(super.isar, super.codec);

  @override
  String get name => 'manas';

  @override
  int get meshKind => MeshEventKinds.manas;

  @override
  Future<List<ManasModel>> signedRows() =>
      isar.manasModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(ManasModel row) => row.signedNostrEvent;

  @override
  Future<ManasModel?> findExisting(MeshEventRecord record) =>
      isar.manasModels.filter().manasIdEqualTo(record.dTag).findFirst();

  @override
  ManasModel? applyRecord(MeshEventRecord record, ManasModel? existing) =>
      ManasBody.applyBody(
        record.content,
        manasId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(ManasModel row) => isar.manasModels.put(row);

  @override
  void stampSigned(ManasModel row, String signedJson, DateTime? removedAt) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
