part of 'vishnu_feed_bloc.dart';

enum VishnuFeedStatus { initial, loading, loaded, loadingMore, error }

class VishnuFeedState {
  const VishnuFeedState({
    this.notes = const [],
    this.profiles = const {},
    this.savedIds = const {},
    this.status = VishnuFeedStatus.initial,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<NoteEntity> notes;
  /// pubkey → ProfileEntity (loaded after each page fetch)
  final Map<String, ProfileEntity> profiles;
  /// set of noteIds the user has saved/bookmarked
  final Set<String> savedIds;
  final VishnuFeedStatus status;
  final bool hasMore;
  final String? errorMessage;

  bool get isEmpty => notes.isEmpty;

  VishnuFeedState copyWith({
    List<NoteEntity>? notes,
    Map<String, ProfileEntity>? profiles,
    Set<String>? savedIds,
    VishnuFeedStatus? status,
    bool? hasMore,
    String? errorMessage,
  }) {
    return VishnuFeedState(
      notes: notes ?? this.notes,
      profiles: profiles ?? this.profiles,
      savedIds: savedIds ?? this.savedIds,
      status: status ?? this.status,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }
}
