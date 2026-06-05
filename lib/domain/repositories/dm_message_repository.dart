import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

abstract class DmMessageRepository {
  /// Idempotent insert. The note must carry a DM `kind` (14/15) and
  /// `conversationId`; `pTagRefs.first` is the receiver pubkey.
  Future<Either<Failure, NoteEntity>> saveMessage(NoteEntity entity);

  Future<Either<Failure, List<NoteEntity>>> getMessages(
    int conversationId, {
    DateTime? before,
    int limit = 30,
  });

  Future<Either<Failure, NoteEntity>> getMessageById(String eventId);
}
