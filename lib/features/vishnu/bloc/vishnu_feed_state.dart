part of 'vishnu_feed_bloc.dart';

enum VishnuFeedStatus { initial, loading, loaded, loadingMore, error }

/// Where the next page comes from.
enum FeedBucket { queue, seen, exhausted }

class VishnuFeedState {
  const VishnuFeedState({
    this.items = const [],
    this.profiles = const {},
    this.savedIds = const {},
    this.status = VishnuFeedStatus.initial,
    this.bucket = FeedBucket.queue,
    this.cursor,
    this.loadedAt,
    this.newCount = 0,
    this.errorMessage,
  });

  /// Unified feed items (Kind 1 notes + Kind 42 channel messages from
  /// joined channels), already in display order.
  final List<NoteEntity> items;

  /// pubkey → ProfileEntity (loaded lazily after each page fetch)
  final Map<String, ProfileEntity> profiles;

  /// IDs the user has saved/bookmarked.
  final Set<String> savedIds;

  final VishnuFeedStatus status;

  /// Which collection the *next* page reads from. `exhausted` = end-of-feed.
  final FeedBucket bucket;

  /// Last loaded item's `created` — passed as `before` to the next page.
  /// Null on first page of a bucket.
  final DateTime? cursor;

  /// The persisted anchor that splits queue from new-buffer.
  final DateTime? loadedAt;

  /// Banner count — number of unseen items newer than [loadedAt].
  final int newCount;

  final String? errorMessage;

  bool get isEmpty => items.isEmpty;
  bool get hasMore => bucket != FeedBucket.exhausted;

  VishnuFeedState copyWith({
    List<NoteEntity>? items,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    VishnuFeedStatus? status,
    FeedBucket? bucket,
    DateTime? cursor,
    bool clearCursor = false,
    DateTime? loadedAt,
    int? newCount,
    String? errorMessage,
  }) {
    return VishnuFeedState(
      items: items ?? this.items,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      status: status ?? this.status,
      bucket: bucket ?? this.bucket,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      loadedAt: loadedAt ?? this.loadedAt,
      newCount: newCount ?? this.newCount,
      errorMessage: errorMessage,
    );
  }
}
