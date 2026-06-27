import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

/// Read-state for messages. Backed by the `UnreadNoteModel` collection where one
/// row = one unread message. Marking read deletes rows; counts are row counts.
abstract class UnreadRepository {
  /// Mark a single message read (delete its unread row; no-op if absent).
  Future<Either<Failure, Unit>> markSeen(String eventId);

  /// Mark every message in a public group read.
  Future<Either<Failure, Unit>> markGroupSeen(String groupId);

  /// Mark every message in a private group read.
  Future<Either<Failure, Unit>> markPrivateGroupSeen(String groupId);

  /// Mark every message in a DM conversation read.
  Future<Either<Failure, Unit>> markConversationSeen(int conversationId);

  /// `created` timestamp of the oldest unread message in a public group, or
  /// null when the group has no unread messages. Marks the read→unread
  /// boundary the group feed anchors on.
  Future<Either<Failure, DateTime?>> oldestUnreadTimeForGroup(
    String groupId,
  );
}
