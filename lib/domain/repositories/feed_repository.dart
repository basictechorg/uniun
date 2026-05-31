import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Vishnu unified feed repository (two-band layout).
///
/// Feed = [seen band, newest-first] then [unseen band, newest-first]. Seen
/// items stay in the feed forever; unseen items move into the seen band as
/// they're scrolled past. New arrivals land in the unseen band by timestamp.
abstract class FeedRepository {
  /// Page of SEEN notes/messages, newest-first.
  Future<Either<Failure, List<NoteEntity>>> getSeenPage({
    required int limit,
    DateTime? before,
  });

  /// Page of UNSEEN notes/messages, newest-first.
  Future<Either<Failure, List<NoteEntity>>> getUnseenPage({
    required int limit,
    DateTime? before,
  });

  /// Unseen notes/messages strictly newer than [topCursor], newest-first.
  /// Used by LoadMore in the unseen band so that any new arrivals (since the
  /// last fetch) are merged into the next page — without disturbing items
  /// already on screen.
  Future<Either<Failure, List<NoteEntity>>> getUnseenAbove({
    required DateTime topCursor,
    required int limit,
  });

  /// Live count of unseen items strictly newer than [topCursor]. Drives the
  /// "↑ N new" pill. Pass `DateTime.fromMillisecondsSinceEpoch(0)` when the
  /// in-memory list is empty.
  Stream<int> watchUnseenAbove(DateTime topCursor);

  /// Flip `isSeen = true` for the given note/public-msg/private-msg id.
  Future<Either<Failure, Unit>> markSeen(String eventId);
}
