import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

abstract class GroupMessageRepository {
  /// Idempotent insert by [NoteEntity.id] (event id). The note must carry
  /// `kind == 42` and `sourceGroupId` set to the group id.
  Future<Either<Failure, NoteEntity>> saveMessage(NoteEntity message);

  /// Group thread messages, newest first.
  Future<Either<Failure, List<NoteEntity>>> getMessagesForGroup({
    required String groupId,
    int limit,
    DateTime? before,
  });

  /// Group messages after [after] (or at/after when [inclusive]), oldest
  /// first. Used for downward pagination through unread / newly-synced
  /// messages.
  Future<Either<Failure, List<NoteEntity>>> getMessagesForGroupAfter({
    required String groupId,
    required DateTime after,
    bool inclusive,
    int limit,
  });

  Future<Either<Failure, NoteEntity?>> getMessageByEventId(String eventId);

  /// Direct replies to a single group message, oldest first.
  Future<Either<Failure, List<NoteEntity>>> getGroupMessageReplies(
    String messageId,
  );

  /// Count of direct replies to a group message.
  Future<Either<Failure, int>> getGroupMessageReplyCount(String messageId);
}
