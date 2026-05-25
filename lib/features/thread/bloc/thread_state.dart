part of 'thread_bloc.dart';

enum ThreadStatus { initial, loading, loaded, error }

enum ThreadPostStatus { idle, posting, posted, error }

class ThreadState {
  const ThreadState({
    this.rootNote,
    this.parentChain = const [],
    this.profiles = const {},
    this.replies = const [],
    this.nestedReplies = const {},
    this.mentionedNotes = const [],
    this.replyText = '',
    this.replyingToId,
    this.replyingToName,
    this.activeTab = 0,
    this.status = ThreadStatus.initial,
    this.postStatus = ThreadPostStatus.idle,
    this.errorMessage,
    this.hasUnread = false,
    this.savedOnly = false,
    this.savedOnlyIds = const {},
  });

  final NoteEntity? rootNote;
  /// Ancestor notes ordered oldest → newest (immediate parent is last).
  /// Empty when the root note is a top-level post.
  final List<NoteEntity> parentChain;
  /// pubkey → ProfileEntity for every author visible in this thread
  final Map<String, ProfileEntity> profiles;
  /// Direct replies to the root note (replyToEventId == rootNote.id)
  final List<NoteEntity> replies;
  /// replyId → its direct replies (one level of nesting)
  final Map<String, List<NoteEntity>> nestedReplies;
  /// Notes referenced by the root note's mention e-tags (not root/reply markers).
  final List<NoteEntity> mentionedNotes;

  final String replyText;
  /// null = composing a reply to the root note
  final String? replyingToId;
  final String? replyingToName;

  final int activeTab; // 0 = Replies, 1 = References
  final ThreadStatus status;
  final ThreadPostStatus postStatus;
  final String? errorMessage;
  /// True when opened from a followed note with unread references.
  final bool hasUnread;
  /// True when opened from Saved Notes — only saved notes are shown.
  final bool savedOnly;
  /// Event IDs of all saved notes (populated when savedOnly=true).
  final Set<String> savedOnlyIds;

  ProfileEntity? profileFor(String pubkey) => profiles[pubkey];

  bool get canPost => replyText.trim().isNotEmpty &&
      postStatus != ThreadPostStatus.posting;

  ThreadState copyWith({
    NoteEntity? rootNote,
    List<NoteEntity>? parentChain,
    Map<String, ProfileEntity>? profiles,
    List<NoteEntity>? replies,
    Map<String, List<NoteEntity>>? nestedReplies,
    List<NoteEntity>? mentionedNotes,
    String? replyText,
    Object? replyingToId = _sentinel,
    Object? replyingToName = _sentinel,
    int? activeTab,
    ThreadStatus? status,
    ThreadPostStatus? postStatus,
    String? errorMessage,
    bool? hasUnread,
    bool? savedOnly,
    Set<String>? savedOnlyIds,
  }) {
    return ThreadState(
      rootNote: rootNote ?? this.rootNote,
      parentChain: parentChain ?? this.parentChain,
      profiles: profiles ?? this.profiles,
      replies: replies ?? this.replies,
      nestedReplies: nestedReplies ?? this.nestedReplies,
      mentionedNotes: mentionedNotes ?? this.mentionedNotes,
      replyText: replyText ?? this.replyText,
      replyingToId: replyingToId == _sentinel
          ? this.replyingToId
          : replyingToId as String?,
      replyingToName: replyingToName == _sentinel
          ? this.replyingToName
          : replyingToName as String?,
      activeTab: activeTab ?? this.activeTab,
      status: status ?? this.status,
      postStatus: postStatus ?? this.postStatus,
      errorMessage: errorMessage,
      hasUnread: hasUnread ?? this.hasUnread,
      savedOnly: savedOnly ?? this.savedOnly,
      savedOnlyIds: savedOnlyIds ?? this.savedOnlyIds,
    );
  }
}

const _sentinel = Object();
