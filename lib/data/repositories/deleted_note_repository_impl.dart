import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/domain/repositories/deleted_note_repository.dart';

@Injectable(as: DeletedNoteRepository)
class DeletedNoteRepositoryImpl extends DeletedNoteRepository {
  final Isar isar;
  DeletedNoteRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, Unit>> deleteNote(String eventId) async {
    try {
      final existing = await isar.deletedNoteModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();

      final row = (existing ?? DeletedNoteModel())
        ..eventId = eventId
        ..deletedAt = DateTime.now()
        ..signedNostrEvent = null
        ..removedAt = null;

      await isar.writeTxn(() async {
        await isar.deletedNoteModels.put(row);

        // Remove the note and its denormalized feed projection.
        await isar.noteModels.filter().eventIdEqualTo(eventId).deleteAll();
        await isar.unreadNoteModels.filter().eventIdEqualTo(eventId).deleteAll();

        // Remove relation edges where this note is parent or child so reply /
        // reference counts on neighbouring notes stay correct.
        await isar.noteRelationModels
            .filter()
            .parentIdEqualTo(eventId)
            .or()
            .childIdEqualTo(eventId)
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
