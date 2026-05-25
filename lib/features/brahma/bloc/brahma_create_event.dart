part of 'brahma_create_bloc.dart';

sealed class BrahmaCreateEvent {
  const BrahmaCreateEvent();
}

final class SubmitNoteEvent extends BrahmaCreateEvent {
  const SubmitNoteEvent({
    required this.content,
    this.rootEventId,
    this.replyToEventId,
  });
  final String content;
  final String? rootEventId;
  final String? replyToEventId;
}

final class SaveDraftEvent extends BrahmaCreateEvent {
  const SaveDraftEvent({
    required this.content,
    this.rootEventId,
    this.replyToEventId,
  });
  final String content;
  final String? rootEventId;
  final String? replyToEventId;
}

final class LoadDraftsEvent extends BrahmaCreateEvent {
  const LoadDraftsEvent();
}

final class DeleteDraftEvent extends BrahmaCreateEvent {
  const DeleteDraftEvent(this.draftId);
  final String draftId;
}

final class PublishDraftEvent extends BrahmaCreateEvent {
  const PublishDraftEvent({
    required this.draftId,
    required this.content,
    this.rootEventId,
    this.replyToEventId,
  });
  final String draftId;
  final String content;
  final String? rootEventId;
  final String? replyToEventId;
}

final class ResetBrahmaEvent extends BrahmaCreateEvent {
  const ResetBrahmaEvent();
}

// ── Mention events ────────────────────────────────────────────────────────────

final class SearchMentionsEvent extends BrahmaCreateEvent {
  const SearchMentionsEvent(this.query);
  final String query;
}

final class AddMentionEvent extends BrahmaCreateEvent {
  const AddMentionEvent(this.note);
  final NoteEntity note;
}

final class RemoveMentionEvent extends BrahmaCreateEvent {
  const RemoveMentionEvent(this.noteId);
  final String noteId;
}

final class ClearMentionSearchEvent extends BrahmaCreateEvent {
  const ClearMentionSearchEvent();
}

/// Fired after pre-filling a draft for edit — loads the referenced notes
/// from Isar so they appear as selected mentions in the compose UI.
final class RestoreDraftMentionsEvent extends BrahmaCreateEvent {
  const RestoreDraftMentionsEvent(this.mentionIds);
  final List<String> mentionIds;
}
