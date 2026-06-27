import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

part 'note_entity.freezed.dart';
part 'note_entity.g.dart';

@freezed
abstract class NoteEntity with _$NoteEntity {
  // Private constructor enables getters on the freezed class.
  const NoteEntity._();

  const factory NoteEntity({
    required String id,
    required String sig,
    required String authorPubkey,
    required String content,
    String? subject,

    /// Nostr event kind: 1 feed note, 42 group message, 14/15 DM,
    /// 9023 private group message. Stored discriminator of the unified Note
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
    /// Non-null when this entity was projected from a Kind-42 public group
    /// message — used by the Vishnu feed to route taps to the group page
    /// instead of the regular thread page. Null for native Kind-1 notes.
    String? sourceGroupId,
    /// Non-null when this entity was projected from a NIP-29 private group
    /// message. Mutually exclusive with [sourceGroupId].
    String? sourcePrivateGroupId,
    /// Pre-rendered chip text shown next to the timestamp on the NoteCard:
    ///   - `#<name>`  for public group messages
    ///   - `🔒 <name>` for private group messages
    ///   - `null`     for native Kind-1 Vishnu notes
    /// Resolved by [FeedRepository] at query time from the group/group rows.
    String? sourceLabel,

    /// Raw self-contained snapshot of the embedded original (the
    /// `embeddedNoteJson` tag / MLS envelope key `"em"`). Source of truth for
    /// [quotedNote]; null when this note quotes nothing. A blanked `sig` inside
    /// it means the embed failed signature verification (see EmbeddedNoteCodec).
    String? embeddedNoteJson,

    /// Pre-resolved one level deep ([quotedNote.quotedNote] is always null).
    /// Built from [embeddedNoteJson] (self-contained, retention-immune). Its
    /// `sig` is empty when the embed is unverified — the renderer badges it.
    NoteEntity? quotedNote,

    /// Pre-resolved attachments. Populated by the data layer when a note is
    /// projected from Isar (mirrors how [quotedNote] and [cachedReplyCount]
    /// are resolved at query time). UI cards read this directly — no per-
    /// card DB lookup.
    ///
    /// Excluded from JSON: this is an in-memory enrichment, not part of the
    /// Nostr wire format — [MediaBlobEntity] isn't itself JSON-serializable.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([]) List<MediaBlobEntity> attachments,
  }) = _NoteEntity;

  factory NoteEntity.fromJson(Map<String, dynamic> json) =>
      _$NoteEntityFromJson(json);

  /// Derived flag — true when the note carries any NIP-92 attachment.
  /// Renderers read this; never set it manually.
  bool get hasMedia => attachments.isNotEmpty;
}

/// The transport a reply to a note must be posted through. Derived from the
/// note itself ([NoteReplyRouting.replyTransport]) — the read side is uniform
/// `NoteEntity`; only the encrypted write transport differs per surface.
enum NoteSource { feed, group, privateGroup, dm }

extension NoteReplyRouting on NoteEntity {
  /// Which transport a reply must use, derived from [kind] + container fields.
  NoteSource get replyTransport {
    if (kind == kGroupMessageKind || sourceGroupId != null) {
      return NoteSource.group;
    }
    if (kind == kPrivateGroupKind || sourcePrivateGroupId != null) {
      return NoteSource.privateGroup;
    }
    if (conversationId != null || kind == kDmTextKind || kind == kDmFileKind) {
      return NoteSource.dm;
    }
    return NoteSource.feed;
  }

  /// DM counterparty pubkey (`pTagRefs.first`); null for non-DM notes.
  String? get dmReceiverPubkey => pTagRefs.isNotEmpty ? pTagRefs.first : null;
}
