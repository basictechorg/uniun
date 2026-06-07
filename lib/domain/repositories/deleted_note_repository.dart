import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

abstract class DeletedNoteRepository {
  /// Deletes a note locally and records a tombstone so the gateway never
  /// re-inserts it on sync. Removes the note row plus its denormalized
  /// projections (unread row, relation edges). Saved/followed bookmarks are
  /// left intact.
  Future<Either<Failure, Unit>> deleteNote(String eventId);
}
