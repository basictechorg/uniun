part of 'brahma_create_bloc.dart';

sealed class BrahmaCreateEvent {
  const BrahmaCreateEvent();
}

final class SubmitNoteEvent extends BrahmaCreateEvent {
  const SubmitNoteEvent({
    required this.content,
    this.rootEventId,
    this.replyToEventId,
    this.publishChain = false,
  });
  final String content;
  final String? rootEventId;
  final String? replyToEventId;

  /// When the composer holds any [BrahmaCreateState.selectedDraftMentions] and
  /// [publishChain] is true, those drafts (and their own draft-ref deps) are
  /// published first, bottom-up, and their freshly-minted event ids are
  /// appended to this note's `e` mention tags. When false (default), draft
  /// references are silently dropped — matches the "publish only this" branch
  /// of the chain dialog.
  final bool publishChain;
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
    this.publishChain = false,
  });
  final String draftId;
  final String content;
  final String? rootEventId;
  final String? replyToEventId;

  /// When true, walk the draft's `draftRefIds` graph and publish unpublished
  /// dependencies first (bottom-up), rewriting their UUIDs to the freshly-
  /// minted event ids before signing each parent. Topological order; cycles
  /// abort with an error.
  ///
  /// When false (default), any unresolved `draftRefIds` on this draft are
  /// silently dropped from the published Kind-1's `e` tags.
  final bool publishChain;
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

/// Adds another *draft* as a reference. Held separately from [AddMentionEvent]
/// (which is for published notes) because drafts ride in `draftRefIds`, not
/// `eTagRefs`.
final class AddDraftMentionEvent extends BrahmaCreateEvent {
  const AddDraftMentionEvent(this.draft);
  final DraftEntity draft;
}

/// Removes a selected reference by its identifier — works for either a note
/// (event id) or a draft (UUID); the handler tries both lists.
final class RemoveMentionEvent extends BrahmaCreateEvent {
  const RemoveMentionEvent(this.noteId);
  final String noteId;
}

final class ClearMentionSearchEvent extends BrahmaCreateEvent {
  const ClearMentionSearchEvent();
}

/// Sets the selected mentions from two id lists — published notes (event ids,
/// resolved via the unified `Note` collection) and other drafts (UUIDs,
/// resolved via the Draft collection). Fired both when pre-filling a draft for
/// edit and when the reference picker returns. Either list may be empty.
final class RestoreDraftMentionsEvent extends BrahmaCreateEvent {
  const RestoreDraftMentionsEvent({
    this.noteIds = const [],
    this.draftIds = const [],
  });
  final List<String> noteIds;
  final List<String> draftIds;
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
