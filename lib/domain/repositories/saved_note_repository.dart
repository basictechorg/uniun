import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';

abstract class SavedNoteRepository {
  /// Save a note (bookmark). Idempotent — second call is a no-op.
  Future<Either<Failure, SavedNoteEntity>> saveNote(NoteEntity note);

  /// Unsave a note.
  Future<Either<Failure, Unit>> unsaveNote(String eventId);

  /// Whether a note is currently saved by the user.
  Future<Either<Failure, bool>> isSaved(String eventId);

  /// All saved notes, newest-saved first.
  Future<Either<Failure, List<SavedNoteEntity>>> getAll();

  /// Count of saved notes that are direct replies in a thread (rootEventId == eventId).
  Future<Either<Failure, int>> getSavedReplyCount(String eventId);

  /// Saved notes that reference [parentId] (its saved replies/references),
  /// resolved via the reference edge table — so it works for channel messages
  /// whose saved eTagRefs are stripped. Each carries its saved-scoped count.
  Future<Either<Failure, List<SavedNoteEntity>>> getSavedReplies(String parentId);

  /// Saved notes that [childId] references (its saved parents/references),
  /// resolved via the edge table — so the parent/reference card renders in the
  /// saved thread even for channel messages with stripped eTagRefs.
  Future<Either<Failure, List<SavedNoteEntity>>> getSavedReferences(String childId);
}
