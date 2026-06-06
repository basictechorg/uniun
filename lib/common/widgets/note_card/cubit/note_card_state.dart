part of 'note_card_cubit.dart';

class NoteCardState {
  const NoteCardState({
    this.profile,
    this.isSaved = false,
    this.isFollowed = false,
  });

  /// Author profile (null until loaded / fetched).
  final ProfileEntity? profile;

  /// Whether the active user has saved this note.
  final bool isSaved;

  /// Whether the active user is following this note's reference graph.
  final bool isFollowed;

  NoteCardState copyWith({
    ProfileEntity? profile,
    bool? isSaved,
    bool? isFollowed,
  }) {
    return NoteCardState(
      profile: profile ?? this.profile,
      isSaved: isSaved ?? this.isSaved,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }
}
