part of 'note_card_cubit.dart';

class NoteCardState {
  const NoteCardState({
    this.profile,
    this.isSaved = false,
    this.isFollowed = false,
    this.isOwnNote = false,
    this.isRemoved = false,
  });

  /// Author profile (null until loaded / fetched).
  final ProfileEntity? profile;

  /// Whether the active user has saved this note.
  final bool isSaved;

  /// Whether the active user is following this note's reference graph.
  final bool isFollowed;

  /// Whether this note was authored by the active user (hides the Block
  /// action — self-block is meaningless).
  final bool isOwnNote;

  /// Whether the user deleted this note locally — the card collapses itself.
  final bool isRemoved;

  NoteCardState copyWith({
    ProfileEntity? profile,
    bool? isSaved,
    bool? isFollowed,
    bool? isOwnNote,
    bool? isRemoved,
  }) {
    return NoteCardState(
      profile: profile ?? this.profile,
      isSaved: isSaved ?? this.isSaved,
      isFollowed: isFollowed ?? this.isFollowed,
      isOwnNote: isOwnNote ?? this.isOwnNote,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }
}
