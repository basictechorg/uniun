import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

abstract class ChannelMessageRepository {
  /// Idempotent insert by [NoteEntity.id] (event id). The note must carry
  /// `kind == 42` and `sourceChannelId` set to the channel id.
  Future<Either<Failure, NoteEntity>> saveMessage(NoteEntity message);

  /// Channel thread messages, newest first.
  Future<Either<Failure, List<NoteEntity>>> getMessagesForChannel({
    required String channelId,
    int limit,
    DateTime? before,
  });

  Future<Either<Failure, NoteEntity?>> getMessageByEventId(String eventId);

  /// Direct replies to a single channel message, oldest first.
  Future<Either<Failure, List<NoteEntity>>> getChannelMessageReplies(
    String messageId,
  );

  /// Count of direct replies to a channel message.
  Future<Either<Failure, int>> getChannelMessageReplyCount(String messageId);
}
