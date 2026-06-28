import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';

part 'draft_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('Draft')
class DraftModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String draftId; // UUID for draft identity

  late String content;

  String? rootEventId; // null = top-level draft
  String? replyToEventId; // null = top-level draft

  late List<String> eTagRefs; // reference graph edges (real Nostr event ids)
  late List<String> pTagRefs; // user mentions
  late List<String> tTags; // topics

  /// References to OTHER drafts (by `draftId` UUID). Stored separately from
  /// [eTagRefs] because they aren't real event ids yet — at publish time we
  /// either drop them (publish-only-this) or rewrite each to the freshly-minted
  /// event id (publish-chain). Carried inside the NIP-37 wrap as `["d-ref", uuid]`
  /// tags on the inner event so the link survives cross-device draft sync.
  List<String> draftRefIds = const [];

  /// Set once this draft has been published. The draft row is kept briefly as a
  /// publish-mapping tombstone (UUID → event id) so other drafts on this and
  /// other devices can resolve their `draftRefIds` to the new event id.
  /// Eligible for cleanup after [DraftCleanupPolicy.publishedTombstoneDays].
  String? publishedAsEventId;

  /// Media staged locally for this draft (same embedded shape as
  /// [NoteModel.attachments]). `url` is null while a draft — the bytes live in
  /// the shared media cache keyed by `sha256`, never on Blossom. They're
  /// uploaded only when the draft is published. Local-only: NOT carried in the
  /// encrypted Kind 31234 wrap, so cross-device sync sees text + tags only.
  List<MediaAttachment> attachments = const [];

  late DateTime createdAt;
  late DateTime updatedAt;

  /// `created_at` of the last NIP-37 Kind 31234 wrap we accepted for this
  /// draft. Used by the inbound handler for last-write-wins reconciliation.
  /// Null on rows created locally that haven't been seen back from the relay.
  DateTime? lastSyncedCreatedAt;

  /// Event id of that same wrap. Seeded into [DraftsSubscription.localIndex]
  /// so NIP-77 negentropy recognises drafts we already hold and the relay
  /// doesn't re-stream them on every reconnect.
  String? lastSyncedEventId;
}

extension DraftModelExtension on DraftModel {
  DraftEntity toDomain() => DraftEntity(
        draftId: draftId,
        content: content,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        eTagRefs: eTagRefs,
        pTagRefs: pTagRefs,
        tTags: tTags,
        draftRefIds: draftRefIds,
        publishedAsEventId: publishedAsEventId,
        attachments: [for (final a in attachments) a.toEntity()],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
