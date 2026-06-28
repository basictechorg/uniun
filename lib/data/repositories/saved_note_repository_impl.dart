import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/saved_note_repository.dart';

@Injectable(as: SavedNoteRepository)
class SavedNoteRepositoryImpl extends SavedNoteRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  final NoteAttachmentsEnricher _attachments;
  SavedNoteRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
    required NoteAttachmentsEnricher attachments,
  })  : _relations = relations,
        _attachments = attachments;

  @override
  Future<Either<Failure, SavedNoteEntity>> saveNote(NoteEntity note) async {
    try {
      final existing = await isar.savedNoteModels
          .where()
          .eventIdEqualTo(note.id)
          .findFirst();
      if (existing != null) return Right(existing.toDomain());

      final model = SavedNoteModel()
        ..eventId = note.id
        ..sig = note.sig
        ..authorPubkey = note.authorPubkey
        ..content = note.content
        ..type = note.type
        ..eTagRefs = note.eTagRefs
        ..rootEventId = note.rootEventId
        ..replyToEventId = note.replyToEventId
        ..pTagRefs = note.pTagRefs
        ..tTags = note.tTags
        ..created = note.created
        ..savedAt = DateTime.now()
        ..sourceGroupId = note.sourceGroupId
        ..sourcePrivateGroupId = note.sourcePrivateGroupId
        ..embeddedNoteJson = note.embeddedNoteJson
        ..attachments = [
          for (final a in note.attachments) _toEmbedded(a),
        ];

      await isar.writeTxn(() async {
        await isar.savedNoteModels.put(model);
      });

      return Right(await _enrichOne(model.toDomain()));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> unsaveNote(String eventId) async {
    try {
      await isar.writeTxn(() async {
        final model = await isar.savedNoteModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (model == null) return;
        await isar.savedNoteModels.delete(model.id);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isSaved(String eventId) async {
    try {
      final exists = await isar.savedNoteModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      return Right(exists != null);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SavedNoteEntity>>> getAll() async {
    try {
      final all = await isar.savedNoteModels
          .where()
          .sortBySavedAtDesc()
          .findAll();
      final savedIds = {for (final m in all) m.eventId};
      final entities = <SavedNoteEntity>[
        for (final m in all)
          m.toDomain().copyWith(
                cachedReplyCount: await _savedReplyCount(m.eventId, savedIds),
                referenceCount: await _savedReferenceCount(m.eventId, savedIds),
              ),
      ];
      return Right(await _enrichMany(entities));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Saved-scoped reply count: how many OTHER saved notes reference [eventId].
  /// Saved-scoped reply count: how many of [eventId]'s replies/references are
  /// themselves saved. Reads the global edge table (so it works even for
  /// group messages, whose saved eTagRefs are stripped) and keeps only edges
  /// whose child is in [savedIds]. The edge set already excludes the thread
  /// root, so there is no nested-reply over-count to subtract.
  Future<int> _savedReplyCount(String eventId, Set<String> savedIds) async {
    final childIds = await _relations.childIdsOf(eventId);
    return childIds.where(savedIds.contains).length;
  }

  /// Saved-scoped outgoing reference count: how many notes [eventId] references
  /// that are themselves saved. Reads the edge table by childId (works for
  /// group messages whose saved eTagRefs are stripped).
  Future<int> _savedReferenceCount(String eventId, Set<String> savedIds) async {
    final parentIds = await _relations.parentIdsOf(eventId);
    return parentIds.where(savedIds.contains).length;
  }

  @override
  Future<Either<Failure, int>> getSavedReplyCount(String eventId) async {
    try {
      final count = await isar.savedNoteModels
          .filter()
          .rootEventIdEqualTo(eventId)
          .count();
      return Right(count);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SavedNoteEntity>>> getSavedReplies(
    String parentId,
  ) async {
    try {
      final childIds = await _relations.childIdsOf(parentId);
      if (childIds.isEmpty) return const Right([]);

      final replies = await isar.savedNoteModels
          .filter()
          .anyOf(childIds.toSet(), (q, id) => q.eventIdEqualTo(id))
          .sortByCreated()
          .findAll();
      if (replies.isEmpty) return const Right([]);

      final savedIds = await _allSavedIds();
      final entities = <SavedNoteEntity>[
        for (final m in replies)
          m.toDomain().copyWith(
                cachedReplyCount: await _savedReplyCount(m.eventId, savedIds),
                referenceCount: await _savedReferenceCount(m.eventId, savedIds),
              ),
      ];
      return Right(await _enrichMany(entities));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SavedNoteEntity>>> getSavedReferences(
    String childId,
  ) async {
    try {
      final parentIds = await _relations.parentIdsOf(childId);
      if (parentIds.isEmpty) return const Right([]);

      final refs = await isar.savedNoteModels
          .filter()
          .anyOf(parentIds.toSet(), (q, id) => q.eventIdEqualTo(id))
          .sortByCreated()
          .findAll();
      if (refs.isEmpty) return const Right([]);

      final savedIds = await _allSavedIds();
      final entities = <SavedNoteEntity>[
        for (final m in refs)
          m.toDomain().copyWith(
                cachedReplyCount: await _savedReplyCount(m.eventId, savedIds),
                referenceCount: await _savedReferenceCount(m.eventId, savedIds),
              ),
      ];
      return Right(await _enrichMany(entities));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }


  Future<Set<String>> _allSavedIds() async {
    final ids =
        await isar.savedNoteModels.where().eventIdProperty().findAll();
    return ids.toSet();
  }

  /// Maps a domain [MediaBlobEntity] back to the embedded Isar row for
  /// persistence. Local-cache state (`localPath`, `downloadedAt`) is NOT
  /// stored here — it's joined per-render from [MediaCacheModel] by
  /// [NoteAttachmentsEnricher].
  MediaAttachment _toEmbedded(MediaBlobEntity e) => MediaAttachment()
    ..sha256 = e.sha256
    ..mime = e.mime
    ..sizeBytes = e.sizeBytes
    ..url = e.serverUrls.isEmpty ? null : e.serverUrls.first
    ..width = e.dim?.width
    ..height = e.dim?.height
    ..blurhash = e.blurhash
    ..filename = e.filename;

  /// One bulk cache lookup across every attachment in [notes]; result is
  /// re-distributed per note via `copyWith`. Replaces the previous
  /// per-note query loop.
  Future<List<SavedNoteEntity>> _enrichMany(
    List<SavedNoteEntity> notes,
  ) async {
    final pooled = <MediaBlobEntity>[
      for (final n in notes) ...n.attachments,
    ];
    if (pooled.isEmpty) return notes;
    final patched = await _attachments.enrichBlobs(pooled);
    final out = <SavedNoteEntity>[];
    var offset = 0;
    for (final n in notes) {
      if (n.attachments.isEmpty) {
        out.add(n);
        continue;
      }
      final slice = patched.sublist(offset, offset + n.attachments.length);
      offset += n.attachments.length;
      out.add(n.copyWith(attachments: slice));
    }
    return out;
  }

  Future<SavedNoteEntity> _enrichOne(SavedNoteEntity n) async {
    if (n.attachments.isEmpty) return n;
    return n.copyWith(
      attachments: await _attachments.enrichBlobs(n.attachments),
    );
  }
}
