import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';

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

    /// Nostr event kind: 1 feed note, 42 channel message, 14/15 DM,
    /// 9023 private channel message. Stored discriminator of the unified Note
    /// collection. Note *roles* (reply/root/reference) are still derived from
    /// rootEventId/replyToEventId, not from kind.
    @Default(1) int kind,
    required NoteType type,
    required List<String> eTagRefs,
    required List<String> pTagRefs,
    required List<String> tTags,
    required DateTime created,

    /// DM conversation id — non-null only when [kind] is 14/15. Used to route
    /// replies back to the correct DM conversation.
    int? conversationId,

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

    /// NIP-18 quote tag — id of the note this one shares/quotes. The renderer
    /// uses this (not content parsing) to decide whether to embed the original.
    String? quoteEventId,
  }) = _NoteEntity;

  factory NoteEntity.fromJson(Map<String, dynamic> json) =>
      _$NoteEntityFromJson(json);
}

/// The transport a reply to a note must be posted through. Derived from the
/// note itself ([NoteReplyRouting.replyTransport]) — the read side is uniform
/// `NoteEntity`; only the encrypted write transport differs per surface.
enum NoteSource { feed, channel, privateChannel, dm }

extension NoteReplyRouting on NoteEntity {
  /// Which transport a reply must use, derived from [kind] + container fields.
  NoteSource get replyTransport {
    if (kind == kChannelMessageKind || sourceChannelId != null) {
      return NoteSource.channel;
    }
    if (kind == kPrivateChannelKind || sourcePrivateGroupId != null) {
      return NoteSource.privateChannel;
    }
    if (conversationId != null || kind == kDmTextKind || kind == kDmFileKind) {
      return NoteSource.dm;
    }
    return NoteSource.feed;
  }

  /// DM counterparty pubkey (`pTagRefs.first`); null for non-DM notes.
  String? get dmReceiverPubkey => pTagRefs.isNotEmpty ? pTagRefs.first : null;
}
