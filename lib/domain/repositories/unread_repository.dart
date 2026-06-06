import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

/// Read-state for messages. Backed by the `UnreadNoteModel` collection where one
/// row = one unread message. Marking read deletes rows; counts are row counts.
abstract class UnreadRepository {
  /// Mark a single message read (delete its unread row; no-op if absent).
  Future<Either<Failure, Unit>> markSeen(String eventId);

  /// Mark every message in a public channel read.
  Future<Either<Failure, Unit>> markChannelSeen(String channelId);

  /// Mark every message in a private channel read.
  Future<Either<Failure, Unit>> markPrivateChannelSeen(String groupId);

  /// Mark every message in a DM conversation read.
  Future<Either<Failure, Unit>> markConversationSeen(int conversationId);
}
