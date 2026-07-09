import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';

part 'saved_note_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('SavedNote')
class SavedNoteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  late String sig;
  late String authorPubkey;
  late String content;

  @Enumerated(EnumType.name)
  late NoteType type;

  late List<String> eTagRefs;

  @Index()
  String? rootEventId;

  @Index()
  String? replyToEventId;

  late List<String> pTagRefs;
  late List<String> tTags;

  late DateTime created;

  @Index()
  late DateTime savedAt;

  /// Source group id if this saved item was originally a Kind-42 public
  /// group message. Used by the saved-notes UI to render the "#group"
  /// chip and to route taps to the group thread page.
  @Name('sourceChannelId') // stored name preserved across channel→group rename
  String? sourceGroupId;

  /// Source group id if this saved item was a NIP-29 private group message.
  /// Mutually exclusive with [sourceGroupId].
  String? sourcePrivateGroupId;

  /// Saved-forever embed-by-value snapshot of the quoted original. Self-
  /// contained (no live-collection lookup), so the embed survives even if the
  /// original is evicted. Source of truth for the resolved `quotedNote`.
  String? embeddedNoteJson;

  /// Saved-forever copy of the note's NIP-92 `imeta` attachments. The live
  /// [NoteModel] could in principle be evicted via a future storage tool;
  /// the saved row owns its media metadata so this view never loses
  /// attachments. SHA-keyed cache state still lives in [MediaCacheModel]
  /// and is joined per-render.
  List<MediaAttachment> attachments = const [];

  /// Signed+encrypted Nostr Kind 30500 event for this row (§3 of the
  /// mesh Nostr-events plan). Wire form on the mesh. Nullable during the
  /// Phase 0a migration; queries that surface saves ignore any row where
  /// it's still null.
  String? signedNostrEvent;

  /// Tombstone marker (§5a). Null on active saves; set to the wall-clock
  /// time we processed a `state=removed` mesh event. Queries filter with
  /// `removedAt == null`.
  @Index()
  DateTime? removedAt;
}

extension SavedNoteModelExtension on SavedNoteModel {
  SavedNoteEntity toDomain() => SavedNoteEntity(
        eventId: eventId,
        sig: sig,
        authorPubkey: authorPubkey,
        content: content,
        type: type,
        eTagRefs: eTagRefs,
        pTagRefs: pTagRefs,
        tTags: tTags,
        created: created,
        savedAt: savedAt,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        sourceGroupId: sourceGroupId,
        sourcePrivateGroupId: sourcePrivateGroupId,
        quotedNote: decodeEmbeddedNote(embeddedNoteJson),
        attachments: [for (final a in attachments) a.toEntity()],
      );
}
