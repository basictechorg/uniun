import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/saved_note_model.dart';

import '../bodies/saved_note_body.dart';
import '../mesh_event_codec.dart';
import 'mesh_record_sync_scope.dart';

/// Kind-30500 SavedNote scope. Addressable slot `d = eventId`. All shared
/// machinery lives in [MeshRecordSyncScope]; this only binds the collection,
/// the kind, and the `d`-tag → row lookup.
class SavedNoteSyncScope extends MeshRecordSyncScope<SavedNoteModel> {
  SavedNoteSyncScope(super.isar, super.codec);

  @override
  String get name => 'savedNote';

  @override
  int get meshKind => MeshEventKinds.savedNote;

  @override
  Future<List<SavedNoteModel>> signedRows() =>
      isar.savedNoteModels.filter().signedNostrEventIsNotNull().findAll();

  @override
  String? signedJsonOf(SavedNoteModel row) => row.signedNostrEvent;

  @override
  Future<SavedNoteModel?> findExisting(MeshEventRecord record) =>
      isar.savedNoteModels.filter().eventIdEqualTo(record.dTag).findFirst();

  @override
  SavedNoteModel? applyRecord(MeshEventRecord record, SavedNoteModel? existing) =>
      SavedNoteBody.applyBody(
        record.content,
        eventId: record.dTag,
        existing: existing,
      );

  @override
  Future<void> putRow(SavedNoteModel row) => isar.savedNoteModels.put(row);

  @override
  void stampSigned(SavedNoteModel row, String signedJson, DateTime? removedAt) {
    row.signedNostrEvent = signedJson;
    row.removedAt = removedAt;
  }
}
