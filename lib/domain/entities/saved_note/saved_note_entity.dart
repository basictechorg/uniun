import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

part 'saved_note_entity.freezed.dart';

@freezed
abstract class SavedNoteEntity with _$SavedNoteEntity {
  const factory SavedNoteEntity({
    required String eventId,
    required String sig,
    required String authorPubkey,
    required String content,
    required NoteType type,
    required List<String> eTagRefs,
    required List<String> pTagRefs,
    required List<String> tTags,
    required DateTime created,
    required DateTime savedAt,

    /// NIP-10 threading markers — let the knowledge graph exclude the thread
    /// root from edges (a deep saved reply links to its direct parent only).
    String? rootEventId,
    String? replyToEventId,
    /// Saved-scoped incoming reply count (saved replies to this note).
    @Default(0) int cachedReplyCount,
    /// Saved-scoped outgoing reference count (saved notes this one references).
    @Default(0) int referenceCount,
    /// Source channel id if the saved item was a Kind-42 public channel msg.
    String? sourceChannelId,
    /// Source group id if the saved item was a NIP-29 private channel msg.
    String? sourcePrivateGroupId,

    /// Resolved from the embedded-by-value snapshot at read time
    /// (`SavedNoteModel.toDomain`). Null when this saved note quotes nothing.
    NoteEntity? quotedNote,
    /// NIP-92 attachments copied at save time. `localPath` / `downloadedAt`
    /// on each entry are joined from [MediaCacheModel] by the repository
    /// before the entity reaches the UI.
    @Default(<MediaBlobEntity>[]) List<MediaBlobEntity> attachments,
  }) = _SavedNoteEntity;
}

extension SavedNoteToNote on SavedNoteEntity {
  /// [savedEventIds] filters eTagRefs to only those that are also saved,
  /// so the ref count matches what savedOnly ThreadPage will actually show.
  /// [sourceLabel] is resolved at the cubit layer via
  /// [ResolveSourceLabelsUseCase] and passed in so the NoteCard can render
  /// the channel/group chip without the entity needing to know about Isar.
  NoteEntity toNoteEntity({
    Set<String>? savedEventIds,
    String? sourceLabel,
  }) =>
      NoteEntity(
        id: eventId,
        sig: sig,
        authorPubkey: authorPubkey,
        content: content,
        type: type,
        eTagRefs: savedEventIds != null
            ? eTagRefs.where((id) => savedEventIds.contains(id)).toList()
            : const [],
        pTagRefs: pTagRefs,
        tTags: tTags,
        created: created,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        cachedReplyCount: cachedReplyCount,
        referenceCount: referenceCount,
        sourceChannelId: sourceChannelId,
        sourcePrivateGroupId: sourcePrivateGroupId,
        sourceLabel: sourceLabel,
        quotedNote: quotedNote,
        attachments: attachments,
      );
}
