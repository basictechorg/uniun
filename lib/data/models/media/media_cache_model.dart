import 'package:isar_community/isar.dart';

part 'media_cache_model.g.dart';

/// One row per blob the user has on disk. Keyed by SHA-256 so two notes
/// referencing the same file share a single cache entry. Inbound notes that
/// the user hasn't downloaded have no row here — the renderer treats their
/// imeta as "remote-only, show download button."
///
/// Manual lifecycle only — there is no automatic GC. The user removes from
/// device via the gallery; saved/own/followed notes' media stays as long as
/// the user wants it.
@Collection(ignore: {'copyWith'})
@Name('MediaCache')
class MediaCacheModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String sha256;

  late String localPath;

  late DateTime downloadedAt;

  /// MIME from the source imeta (upload-time or download-time). Stored so
  /// the renderer can pick image vs file UI without re-stat-ing the disk
  /// or joining against a NoteModel — useful right after upload, before
  /// the note is saved/published.
  String mime = 'application/octet-stream';

  /// File size in bytes (the upload bytes or the downloaded length).
  int sizeBytes = 0;
}
