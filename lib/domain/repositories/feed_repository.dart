import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Vishnu unified feed repository.
///
/// Merges two collections — Kind 1 notes and Kind 42 public channel messages
/// from joined channels — under one read model. A note is "unread" iff an
/// `UnreadNote` row exists for its eventId. The feed drains in two phases:
///
///   - **Unread**: any note with an unread row — drained first, `created` desc,
///     regardless of the [feedLoadedAt] anchor (newly arrived unread included).
///   - **Seen**:   no unread row — shown after unread, `created` desc.
///
/// The [feedLoadedAt] anchor is used only for the "X new notes" banner count.
abstract class FeedRepository {
  /// Reads the persisted anchor (creates it as `now` on first call).
  Future<Either<Failure, DateTime>> getOrInitFeedLoadedAt();

  /// Snaps the anchor forward (called on banner tap / pull-to-refresh).
  Future<Either<Failure, Unit>> setFeedLoadedAt(DateTime ts);

  /// Unread phase — feed-eligible notes/channel-msgs that still have an unread
  /// row, `created` desc. Returns up to [limit] items, skipping any eventId in
  /// [excludeIds] (the already-loaded set). No `before` cursor: new arrivals
  /// are newer than any cursor, and the unread collection self-prunes (rows are
  /// deleted on mark-seen) so it stays small.
  Future<Either<Failure, List<NoteEntity>>> getUnread({
    required int limit,
    required Set<String> excludeIds,
  });

  /// Seen phase — feed-eligible notes/channel-msgs with NO unread row,
  /// `created` desc, paginated by [before].
  Future<Either<Failure, List<NoteEntity>>> getSeen({
    required int limit,
    DateTime? before,
  });

  /// Live count of new arrivals since [loadedAt]. Drives the "X new notes"
  /// banner. Emits the current value immediately, then again whenever the
  /// underlying collections change.
  Stream<int> watchNewBufferCount(DateTime loadedAt);

  /// Mark a note or channel message seen by deleting its unread row.
  /// No-op if already seen or unknown.
  Future<Either<Failure, Unit>> markSeen(String eventId);
}
