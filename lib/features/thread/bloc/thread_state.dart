part of 'thread_bloc.dart';

enum ThreadStatus { initial, loading, loaded, error }

enum ThreadPostStatus { idle, posting, error }

class ThreadState {
  const ThreadState({
    this.status = ThreadStatus.initial,
    this.root,
    this.parentNotes = const [],
    this.mentionedNotes = const [],
    this.replies = const [],
    this.profiles = const {},
    this.postStatus = ThreadPostStatus.idle,
    this.errorMessage,
    this.savedOnly = false,
  });

  final ThreadStatus status;

  /// The resolved root, carrying its source + routing info for reply posting.
  final ResolvedNote? root;
  final List<NoteEntity> parentNotes;
  final List<NoteEntity> mentionedNotes;
  final List<NoteEntity> replies;
  final Map<String, ProfileEntity> profiles;
  final ThreadPostStatus postStatus;
  final String? errorMessage;
  final bool savedOnly;

  NoteEntity? get rootNote => root?.note;

  ThreadState copyWith({
    ThreadStatus? status,
    ResolvedNote? root,
    List<NoteEntity>? parentNotes,
    List<NoteEntity>? mentionedNotes,
    List<NoteEntity>? replies,
    Map<String, ProfileEntity>? profiles,
    ThreadPostStatus? postStatus,
    String? errorMessage,
    bool? savedOnly,
  }) {
    return ThreadState(
      status: status ?? this.status,
      root: root ?? this.root,
      parentNotes: parentNotes ?? this.parentNotes,
      mentionedNotes: mentionedNotes ?? this.mentionedNotes,
      replies: replies ?? this.replies,
      profiles: profiles ?? this.profiles,
      postStatus: postStatus ?? this.postStatus,
      errorMessage: errorMessage,
      savedOnly: savedOnly ?? this.savedOnly,
    );
  }
}
