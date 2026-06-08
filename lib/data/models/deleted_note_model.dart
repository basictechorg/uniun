import 'package:isar_community/isar.dart';

part 'deleted_note_model.g.dart';

/// A note the active identity has deleted locally. Stored locally only — the
/// gateway isolate keeps an in-memory set of these and drops every inbound
/// event whose `id` matches, before persisting anything to Isar. This is how a
/// deleted note never resyncs. Honors Feed Freedom: the note is not deleted on
/// Nostr (no NIP-09 / Kind 5), only suppressed on this device.
@Collection(ignore: {'copyWith'})
@Name('DeletedNote')
class DeletedNoteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String eventId;

  late DateTime deletedAt;
}
