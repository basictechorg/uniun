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
@Collection(ignore: {'copyWith'})
@Name('ManasNoteLink')
class ManasNoteLinkModel {
  Id id = Isar.autoIncrement;

  @Index(composite: [CompositeIndex('noteId')], unique: true)
  late String manasId;

  @Index()
  late String noteId;

  late DateTime addedAt;
}
