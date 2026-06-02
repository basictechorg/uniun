import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/note_type.dart';

part 'note_entity.freezed.dart';
part 'note_entity.g.dart';

@freezed
abstract class NoteEntity with _$NoteEntity {
  const factory NoteEntity({
    required String id,
    required String sig,
    required String authorPubkey,
    required String content,
    String? subject,
    required NoteType type,
    required List<String> eTagRefs,
    required List<String> pTagRefs,
    required List<String> tTags,
    required DateTime created,
    required bool isSeen,

    /// NIP-10 "root" marker — null means this IS a top-level note.
    String? rootEventId,

    /// NIP-10 "reply" marker — the direct parent note this replies to.
    String? replyToEventId,
    /// Incoming reply count — notes that reference this one. From the edge table.
    @Default(0) int cachedReplyCount,
    /// Outgoing reference count — notes this one references. From the edge table.
    @Default(0) int referenceCount,
    /// Non-null when this entity was projected from a Kind-42 public channel
    /// message — used by the Vishnu feed to route taps to the channel page
    /// instead of the regular thread page. Null for native Kind-1 notes.
    String? sourceChannelId,
    /// Non-null when this entity was projected from a NIP-29 private channel
    /// message. Mutually exclusive with [sourceChannelId].
    String? sourcePrivateGroupId,
    /// Pre-rendered chip text shown next to the timestamp on the NoteCard:
    ///   - `#<name>`  for public channel messages
    ///   - `🔒 <name>` for private channel messages
    ///   - `null`     for native Kind-1 Vishnu notes
    /// Resolved by [FeedRepository] at query time from the channel/group rows.
    String? sourceLabel,
  }) = _NoteEntity;

  factory NoteEntity.fromJson(Map<String, dynamic> json) =>
      _$NoteEntityFromJson(json);
}
