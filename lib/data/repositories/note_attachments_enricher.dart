import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/media/media_blob_model.dart';
import 'package:uniun/data/models/media/note_media_ref_model.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Bulk-resolves NIP-92 `imeta` attachments for a list of notes. Every
/// repository that projects [NoteEntity] from Isar goes through here so the
/// UI never has to spawn its own DB lookup per card — same pattern as
/// `cachedReplyCount` / `quotedNote` enrichment.
///
/// One query into [NoteMediaRefModel] for the link rows + one query into
/// [MediaBlobModel] for the unique sha256s, then assemble in memory. Notes
/// where `hasMedia == false` are skipped — no wasted I/O for text-only
/// feeds.
@lazySingleton
class NoteAttachmentsEnricher {
  NoteAttachmentsEnricher({required this.isar});
  final Isar isar;

  /// Returns the input list with `attachments` populated on every entity
  /// that has [NoteEntity.hasMedia] set. Other entities are returned
  /// unchanged.
  Future<List<NoteEntity>> enrichAll(List<NoteEntity> notes) async {
    final mediaIds = <String>[
      for (final n in notes)
        if (n.hasMedia) n.id,
    ];
    if (mediaIds.isEmpty) return notes;

    final byNoteId = await _resolveByNoteId(mediaIds);
    if (byNoteId.isEmpty) return notes;

    return [
      for (final n in notes)
        byNoteId.containsKey(n.id)
            ? n.copyWith(attachments: byNoteId[n.id]!)
            : n,
    ];
  }

  /// Resolves a single note's attachments. Use in code paths that already
  /// have one entity in hand (resolveById, single-fetch).
  Future<NoteEntity> enrichOne(NoteEntity note) async {
    if (!note.hasMedia) return note;
    final byNoteId = await _resolveByNoteId([note.id]);
    final list = byNoteId[note.id];
    if (list == null || list.isEmpty) return note;
    return note.copyWith(attachments: list);
  }

  Future<Map<String, List<MediaBlobEntity>>> _resolveByNoteId(
    List<String> noteIds,
  ) async {
    final refs = await isar.noteMediaRefModels
        .filter()
        .anyOf(noteIds, (q, id) => q.noteEventIdEqualTo(id))
        .findAll();
    if (refs.isEmpty) return const {};

    final uniqueShas = refs.map((r) => r.mediaSha256).toSet().toList();
    final blobs = await isar.mediaBlobModels
        .filter()
        .anyOf(uniqueShas, (q, sha) => q.sha256EqualTo(sha))
        .findAll();
    final blobBySha = {for (final b in blobs) b.sha256: b.toDomain()};

    final out = <String, List<MediaBlobEntity>>{};
    for (final r in refs) {
      final blob = blobBySha[r.mediaSha256];
      if (blob == null) continue;
      (out[r.noteEventId] ??= []).add(blob);
    }
    return out;
  }
}
