part of 'vishnu_feed_bloc.dart';

enum VishnuFeedStatus { initial, loading, loaded, loadingMore, empty, error }

/// Which band the *next* page reads from. `exhausted` = end-of-feed.
enum FeedBand { seen, unseen, exhausted }

class VishnuFeedState {
  const VishnuFeedState({
    this.items = const [],
    this.profiles = const {},
    this.savedIds = const {},
    this.status = VishnuFeedStatus.initial,
    this.band = FeedBand.seen,
    this.cursor,
    this.topUnseenCursor,
    this.newAboveCount = 0,
    this.errorMessage,
  });

  /// Combined feed items in display order — seen rows first (newest-first),
  /// then unseen rows (newest-first).
  final List<NoteEntity> items;
  final Map<String, ProfileEntity> profiles;
  final Set<String> savedIds;
  final VishnuFeedStatus status;
  final FeedBand band;

  /// `created` of the last item in the current band (cursor for the next page
  /// fetch from the same band). Null when starting a new band.
  final DateTime? cursor;

  /// `created` of the newest unseen item already loaded into [items]. Used
  /// both by LoadMore (to fetch any newer-arrived unseen items) and by the
  /// banner watch. Null until the unseen band has been entered.
  final DateTime? topUnseenCursor;

  /// Pill count — unseen items newer than [topUnseenCursor].
  final int newAboveCount;

  final String? errorMessage;

  bool get hasMore => band != FeedBand.exhausted;
  bool get isEmpty => items.isEmpty;

  VishnuFeedState copyWith({
    List<NoteEntity>? items,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    VishnuFeedStatus? status,
    FeedBand? band,
    DateTime? cursor,
    bool clearCursor = false,
    DateTime? topUnseenCursor,
    bool clearTopUnseen = false,
    int? newAboveCount,
    String? errorMessage,
  }) {
    return VishnuFeedState(
      items: items ?? this.items,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      status: status ?? this.status,
      band: band ?? this.band,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      topUnseenCursor: clearTopUnseen
          ? null
          : (topUnseenCursor ?? this.topUnseenCursor),
      newAboveCount: newAboveCount ?? this.newAboveCount,
      errorMessage: errorMessage,
    );
  }
}
