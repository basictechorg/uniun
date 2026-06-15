import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/media/media_cache_model.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Patches `localPath` / `downloadedAt` onto a note's attachments by looking
/// up [MediaCacheModel] rows. The imeta metadata itself already lives on
/// the note (as embedded [MediaAttachment]s) and arrives in
/// [NoteEntity.attachments] via `NoteModel.toDomain()`.
///
/// One bulk query into [MediaCacheModel] for the unique sha256s referenced
/// by the input notes. Notes with no attachments are returned unchanged.
@lazySingleton
class NoteAttachmentsEnricher {
  NoteAttachmentsEnricher({required this.isar});
  final Isar isar;

  /// Returns the input list with cache state patched onto every entity that
  /// has any attachments. Other entities are returned unchanged.
  Future<List<NoteEntity>> enrichAll(List<NoteEntity> notes) async {
    final shas = <String>{
      for (final n in notes)
        if (n.hasMedia)
          for (final a in n.attachments) a.sha256,
    };
    if (shas.isEmpty) return notes;

    final cache = await _cacheBySha(shas);
    if (cache.isEmpty) return notes;

    return [
      for (final n in notes) _patch(n, cache),
    ];
  }

  /// Single-note variant for code paths that already hold one entity.
  Future<NoteEntity> enrichOne(NoteEntity note) async {
    if (!note.hasMedia) return note;
    final shas = note.attachments.map((a) => a.sha256).toSet();
    final cache = await _cacheBySha(shas);
    if (cache.isEmpty) return note;
    return _patch(note, cache);
  }

  NoteEntity _patch(NoteEntity n, Map<String, MediaCacheModel> cache) {
    if (!n.hasMedia) return n;
    final patched = <MediaBlobEntity>[
      for (final a in n.attachments)
        cache.containsKey(a.sha256)
            ? a.copyWith(
                localPath: cache[a.sha256]!.localPath,
                downloadedAt: cache[a.sha256]!.downloadedAt,
              )
            : a,
    ];
    return n.copyWith(attachments: patched);
  }

  Future<Map<String, MediaCacheModel>> _cacheBySha(Set<String> shas) async {
    if (shas.isEmpty) return const {};
    final rows = await isar.mediaCacheModels
        .filter()
        .anyOf(shas.toList(), (q, sha) => q.sha256EqualTo(sha))
        .findAll();
    return {for (final r in rows) r.sha256: r};
  }
}
