part of 'brahma_create_bloc.dart';

enum BrahmaCreateStatus { idle, submitting, success, error, loadingDrafts, draftSaved }

class BrahmaCreateState {
  const BrahmaCreateState({
    this.status = BrahmaCreateStatus.idle,
    this.errorMessage,
    this.drafts = const [],
    this.selectedMentions = const [],
    this.mentionResults = const [],
    this.isMentionSearching = false,
    this.pendingMedia = const [],
    this.isAttachingMedia = false,
  });

  final BrahmaCreateStatus status;
  final String? errorMessage;
  final List<DraftEntity> drafts;

  /// Notes the user has selected to mention (e-tag with "mention" marker).
  final List<NoteEntity> selectedMentions;

  /// Search results from the mention picker search.
  final List<NoteEntity> mentionResults;

  /// True while a mention search is in flight.
  final bool isMentionSearching;

  /// Media the user has attached but NOT yet uploaded — held locally and
  /// pushed to Blossom only when the note is submitted. Each becomes an
  /// `imeta` tag (NIP-92) after that upload.
  final List<PickedMedia> pendingMedia;

  /// True while a freshly-picked file is being prepared (blurhash + dimensions
  /// computed off-thread). The composer disables the attach button meanwhile.
  final bool isAttachingMedia;

  bool get isSubmitting => status == BrahmaCreateStatus.submitting;

  BrahmaCreateState copyWith({
    BrahmaCreateStatus? status,
    String? errorMessage,
    List<DraftEntity>? drafts,
    List<NoteEntity>? selectedMentions,
    List<NoteEntity>? mentionResults,
    bool? isMentionSearching,
    List<PickedMedia>? pendingMedia,
    bool? isAttachingMedia,
  }) {
    return BrahmaCreateState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      drafts: drafts ?? this.drafts,
      selectedMentions: selectedMentions ?? this.selectedMentions,
      mentionResults: mentionResults ?? this.mentionResults,
      isMentionSearching: isMentionSearching ?? this.isMentionSearching,
      pendingMedia: pendingMedia ?? this.pendingMedia,
      isAttachingMedia: isAttachingMedia ?? this.isAttachingMedia,
    );
  }
}

