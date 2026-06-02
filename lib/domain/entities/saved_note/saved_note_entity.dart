import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/note_type.dart';
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
    /// Saved-scoped incoming reply count (saved replies to this note).
    @Default(0) int cachedReplyCount,
    /// Saved-scoped outgoing reference count (saved notes this one references).
    @Default(0) int referenceCount,
    /// Source channel id if the saved item was a Kind-42 public channel msg.
    String? sourceChannelId,
    /// Source group id if the saved item was a NIP-29 private channel msg.
    String? sourcePrivateGroupId,
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
        isSeen: true,
        cachedReplyCount: cachedReplyCount,
        referenceCount: referenceCount,
        sourceChannelId: sourceChannelId,
        sourcePrivateGroupId: sourcePrivateGroupId,
        sourceLabel: sourceLabel,
      );
}
