import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Finds notes/messages in the unified `Note` collection by their
/// globally-unique event id. This is what lets one thread screen render a note
/// regardless of which surface (feed / group / private group / DM) produced
/// it, and lets a note reference a message from any other surface. Reply
/// routing is derived from the resolved [NoteEntity] itself (see
/// `NoteReplyRouting.replyTransport`).
abstract class NoteResolverRepository {
  /// Resolves [id] from the `Note` collection. `notFoundFailure` when absent.
  Future<Either<Failure, NoteEntity>> resolveById(String id);

  /// Lightweight lookup returning just the [NoteEntity] (parent / mentions).
  /// Returns `null` (as `Right(null)`) when not found anywhere.
  Future<Either<Failure, NoteEntity?>> resolveNoteById(String id);

  /// Comments on [id] — every note that references it in the edge table
  /// (NIP-10 replies AND mention-references), sorted oldest→newest. Matches the
  /// note's comment count; the thread root is excluded (deep replies belong
  /// under their direct parent).
  Future<Either<Failure, List<NoteEntity>>> resolveReplies(String id);

  /// Resolves each id in [ids], skipping any that aren't found.
  Future<Either<Failure, List<NoteEntity>>> resolveMany(List<String> ids);

  /// Populates [NoteEntity.quotedNote] one level deep via a single batched
  /// query. Does NOT recurse — `quotedNote.quotedNote` is always null.
  Future<List<NoteEntity>> enrichWithQuotes(List<NoteEntity> notes);
}
