import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/gana_model.dart';

import '../bodies/gana_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30520 Gana definition scope. Addressable slot `d = ganaId`. All shared
/// machinery lives in [MeshRecordSyncScope]. Per-device runtime cursor state is
/// preserved by [GanaBody.applyBody] (never round-trips the wire).
class GanaSyncScope extends MeshRecordSyncScope<GanaModel> {
  GanaSyncScope(super.isar, super.codec);

  @override
  String get name => 'gana';

  @override
  int get meshKind => MeshEventKinds.gana;

  @override
  Future<List<GanaModel>> signedRows() =>
      isar.ganaModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(GanaModel row) => row.signedNostrEvent;

  @override
  Future<GanaModel?> findExisting(MeshEventRecord record) =>
      isar.ganaModels.filter().ganaIdEqualTo(record.dTag).findFirst();

  @override
  GanaModel? applyRecord(MeshEventRecord record, GanaModel? existing) =>
      GanaBody.applyBody(
        record.content,
        ganaId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(GanaModel row) => isar.ganaModels.put(row);

  @override
  void stampSigned(GanaModel row, String signedJson, DateTime? removedAt) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
