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
    this.draftId,
    this.rootEventId,
    this.replyToEventId,
  });
  final String content;

  /// When set (draft is being edited), the existing draft is updated in place
  /// instead of creating a new one — so re-saving keeps the same row + media.
  final String? draftId;
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

/// Sets the selected mentions from a list of note ids — loads each note from
/// Isar so they appear as selected mentions in the compose UI. Fired both when
/// pre-filling a draft for edit and when the reference picker returns.
final class RestoreDraftMentionsEvent extends BrahmaCreateEvent {
  const RestoreDraftMentionsEvent(this.mentionIds);
  final List<String> mentionIds;
}

// ── Media attachment events ───────────────────────────────────────────────────

/// User picked a Photo / Video / File. The picker already computed dimensions
/// + blurhash; the bloc just holds the [PickedMedia] in
/// [BrahmaCreateState.pendingMedia] and uploads it to Blossom only on submit.
final class AttachMediaEvent extends BrahmaCreateEvent {
  const AttachMediaEvent(this.media);
  final PickedMedia media;
}

final class RemoveAttachedMediaEvent extends BrahmaCreateEvent {
  const RemoveAttachedMediaEvent(this.sha256);
  final String sha256;
}

/// Re-hydrate a draft's staged media into [BrahmaCreateState.pendingMedia] when
/// the draft is opened for editing — reads the cached bytes back so the
/// composer shows the thumbnails and re-save / publish carry the media.
final class RestoreDraftMediaEvent extends BrahmaCreateEvent {
  const RestoreDraftMediaEvent(this.attachments);
  final List<MediaBlobEntity> attachments;
}
