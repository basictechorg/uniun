part of 'vishnu_feed_bloc.dart';

enum VishnuFeedStatus { initial, loading, loaded, loadingMore, error }

class VishnuFeedState {
  const VishnuFeedState({
    this.items = const [],
    this.profiles = const {},
    this.savedIds = const {},
    this.status = VishnuFeedStatus.initial,
    this.seenCursor,
    this.exhausted = false,
    this.loadedAt,
    this.newCount = 0,
    this.errorMessage,
  });

  /// Unified feed items (Kind 1 notes + Kind 42 group messages from
  /// joined groups), already in display order.
  final List<NoteEntity> items;

  /// pubkey → ProfileEntity (loaded lazily after each page fetch)
  final Map<String, ProfileEntity> profiles;

  /// IDs the user has saved/bookmarked.
  final Set<String> savedIds;

  final VishnuFeedStatus status;

  /// Last loaded seen-phase item's `created` — passed as `before` to the next
  /// seen page. Null until the unread phase yields to the seen phase.
  final DateTime? seenCursor;

  /// End-of-feed: both unread and seen phases are dry. Stops infinite scroll.
  final bool exhausted;

  /// The persisted anchor that drives the "X new notes" banner count.
  final DateTime? loadedAt;

  /// Banner count — number of unseen items newer than [loadedAt].
  final int newCount;

  final String? errorMessage;

  bool get isEmpty => items.isEmpty;
  bool get hasMore => !exhausted;

  VishnuFeedState copyWith({
    List<NoteEntity>? items,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    VishnuFeedStatus? status,
    DateTime? seenCursor,
    bool clearSeenCursor = false,
    bool? exhausted,
    DateTime? loadedAt,
    int? newCount,
    String? errorMessage,
  }) {
    return VishnuFeedState(
      items: items ?? this.items,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      status: status ?? this.status,
      seenCursor: clearSeenCursor ? null : (seenCursor ?? this.seenCursor),
      exhausted: exhausted ?? this.exhausted,
      loadedAt: loadedAt ?? this.loadedAt,
      newCount: newCount ?? this.newCount,
      errorMessage: errorMessage,
    );
  }
}
