import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/saved_note/saved_note_entity.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/saved_note_repository.dart';

@Injectable(as: SavedNoteRepository)
class SavedNoteRepositoryImpl extends SavedNoteRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  SavedNoteRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
  }) : _relations = relations;

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
        ..sourceChannelId = note.sourceChannelId
        ..sourcePrivateGroupId = note.sourcePrivateGroupId;

      await isar.writeTxn(() async {
        await isar.savedNoteModels.put(model);
      });

      return Right(model.toDomain());
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
      return Right(<SavedNoteEntity>[
        for (final m in all)
          m.toDomain().copyWith(
                cachedReplyCount: await _savedReplyCount(m.eventId, savedIds),
                referenceCount: await _savedReferenceCount(m.eventId, savedIds),
              ),
      ]);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Saved-scoped reply count: how many OTHER saved notes reference [eventId].
  /// Saved-scoped reply count: how many of [eventId]'s replies/references are
  /// themselves saved. Reads the global edge table (so it works even for
  /// channel messages, whose saved eTagRefs are stripped) and keeps only edges
  /// whose child is in [savedIds]. The edge set already excludes the thread
  /// root, so there is no nested-reply over-count to subtract.
  Future<int> _savedReplyCount(String eventId, Set<String> savedIds) async {
    final childIds = await _relations.childIdsOf(eventId);
    return childIds.where(savedIds.contains).length;
  }

  /// Saved-scoped outgoing reference count: how many notes [eventId] references
  /// that are themselves saved. Reads the edge table by childId (works for
  /// channel messages whose saved eTagRefs are stripped).
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
      return Right(<SavedNoteEntity>[
        for (final m in replies)
          m.toDomain().copyWith(
                cachedReplyCount: await _savedReplyCount(m.eventId, savedIds),
                referenceCount: await _savedReferenceCount(m.eventId, savedIds),
              ),
      ]);
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
      return Right(<SavedNoteEntity>[
        for (final m in refs)
          m.toDomain().copyWith(
                cachedReplyCount: await _savedReplyCount(m.eventId, savedIds),
                referenceCount: await _savedReferenceCount(m.eventId, savedIds),
              ),
      ]);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<Set<String>> _allSavedIds() async {
    final ids =
        await isar.savedNoteModels.where().eventIdProperty().findAll();
    return ids.toSet();
  }
}
