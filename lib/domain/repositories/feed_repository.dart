import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Vishnu unified feed repository.
///
/// Merges two collections — Kind 1 notes and Kind 42 public channel messages
/// from joined channels — under one read model. Three derived buckets keyed
/// off the persisted [feedLoadedAt] anchor + per-row `isSeen`:
///
///   - **New buffer**: `!isSeen && created >  feedLoadedAt` — banner only.
///   - **Queue**:      `!isSeen && created <= feedLoadedAt` — top of feed.
///   - **Seen**:       `isSeen`                             — after queue.
abstract class FeedRepository {
  /// Reads the persisted anchor (creates it as `now` on first call).
  Future<Either<Failure, DateTime>> getOrInitFeedLoadedAt();

  /// Snaps the anchor forward (called on banner tap / pull-to-refresh).
  Future<Either<Failure, Unit>> setFeedLoadedAt(DateTime ts);

  /// Bucket **B** — unseen notes/channel-msgs created at-or-before [loadedAt].
  /// Returns up to [limit] items, merged and sorted by `created` desc.
  /// [before] is the previous page's last item's created (cursor).
  Future<Either<Failure, List<NoteEntity>>> getUnseenQueue({
    required DateTime loadedAt,
    required int limit,
    DateTime? before,
  });

  /// Bucket **C** — seen notes/channel-msgs, `created` desc, paginated by
  /// [before].
  Future<Either<Failure, List<NoteEntity>>> getSeen({
    required int limit,
    DateTime? before,
  });

  /// Live count of bucket **A** — new arrivals since [loadedAt]. Drives the
  /// "X new notes" banner. Emits the current value immediately, then again
  /// whenever the underlying collections change.
  Stream<int> watchNewBufferCount(DateTime loadedAt);

  /// Flip `isSeen = true` for a note or channel message. The repo figures out
  /// which collection the id lives in. No-op if already seen or unknown.
  Future<Either<Failure, Unit>> markSeen(String eventId);
}
