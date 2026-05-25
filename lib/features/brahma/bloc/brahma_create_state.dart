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

  bool get isSubmitting => status == BrahmaCreateStatus.submitting;

  BrahmaCreateState copyWith({
    BrahmaCreateStatus? status,
    String? errorMessage,
    List<DraftEntity>? drafts,
    List<NoteEntity>? selectedMentions,
    List<NoteEntity>? mentionResults,
    bool? isMentionSearching,
  }) {
    return BrahmaCreateState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      drafts: drafts ?? this.drafts,
      selectedMentions: selectedMentions ?? this.selectedMentions,
      mentionResults: mentionResults ?? this.mentionResults,
      isMentionSearching: isMentionSearching ?? this.isMentionSearching,
    );
  }
}

