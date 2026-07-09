import 'package:isar_community/isar.dart';

part 'manas_note_link_model.g.dart';

/// Junction row: one Manas → one note membership. A note may belong to many
/// Manases (and vice-versa) — composite uniqueness on (manasId, noteId)
/// prevents duplicate links. Standalone index on noteId answers the reverse
/// lookup "which Manases is this note in?".
///
/// `noteId` is a free-form id string — Nostr `eventId` for saved/own notes,
/// `draftId` UUID for drafts. Resolution to the underlying row lives in the
/// consumer (form bloc / graph bloc).
///
/// Phase 4 mesh sync (Kind 30511 — membership edge): [signedNostrEvent]
/// carries the signed + NIP-44 self-encrypted event whose `d` tag is
/// `"$manasId:$noteId"`. Undo (remove-from-Manas) publishes a NEW event with
/// the same `d`, a newer `created_at`, and `state = removed`; the receiver
/// keeps the row (does NOT delete it) but sets [removedAt] so future
/// negentropy passes still surface the tombstone. See plan §5a.
@Collection(ignore: {'copyWith'})
@Name('ManasNoteLink')
class ManasNoteLinkModel {
  Id id = Isar.autoIncrement;

  @Index(composite: [CompositeIndex('noteId')], unique: true)
  late String manasId;

  @Index()
  late String noteId;

  late DateTime addedAt;

  /// Signed+encrypted Nostr Kind 30511 event for this row (§3). Nullable
  /// during Phase 4 migration.
  String? signedNostrEvent;

  /// Tombstone marker (§5a). Null on active links.
  @Index()
  DateTime? removedAt;
}
