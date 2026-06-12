import 'package:isar_community/isar.dart';

part 'note_media_ref_model.g.dart';

/// Join table: which notes reference which blobs.
///
/// Two indexed columns so both directions are O(1):
///   - by `noteEventId` — "what media does this note attach?"
///   - by `mediaSha256` — "what notes still reference this blob?" (GC pass)
///
/// One row per (note, blob) pair. The composite uniqueness is enforced by
/// the inbound handler (upsert) and the upload path (insert-once); Isar's
/// own composite-unique would force a non-Id primary key, so we keep the
/// auto-id and dedupe in code.
@Collection(ignore: {'copyWith'})
@Name('NoteMediaRef')
class NoteMediaRefModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String noteEventId;

  @Index()
  late String mediaSha256;
}
