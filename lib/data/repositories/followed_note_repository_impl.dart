import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/domain/entities/followed_note/followed_note_entity.dart';
import 'package:uniun/domain/repositories/followed_note_repository.dart';
import 'package:uniun/features/mesh/sync/bodies/followed_note_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

@Injectable(as: FollowedNoteRepository)
class FollowedNoteRepositoryImpl extends FollowedNoteRepository {
  final Isar isar;
  final MeshEventSigner _signer;
  FollowedNoteRepositoryImpl({
    required this.isar,
    required MeshEventSigner signer,
  }) : _signer = signer;

  /// Child event IDs of [rootEventId] recorded in the reference edge table.
  Future<List<String>> _childIdsOf(String rootEventId) async {
    final edges = await isar.noteRelationModels
        .filter()
        .parentIdEqualTo(rootEventId)
        .findAll();
    return edges.map((e) => e.childId).toList(growable: false);
  }

  /// Badge count = number of children that STILL have a live unread row.
  /// Reading a child deletes its unread row → count drops naturally.
  Future<int> _deriveUnreadRefCount(String rootEventId) async {
    final childIds = await _childIdsOf(rootEventId);
    if (childIds.isEmpty) return 0;
    return isar.unreadNoteModels
        .filter()
        .anyOf(childIds, (q, id) => q.eventIdEqualTo(id))
        .count();
  }

  Future<FollowedNoteEntity> _toEntity(FollowedNoteModel model) async {
    final unreadRefs = await _deriveUnreadRefCount(model.eventId);
    return FollowedNoteEntity(
      eventId: model.eventId,
      contentPreview: model.contentPreview,
      followedAt: model.followedAt,
      newReferenceCount: unreadRefs,
    );
  }

  @override
  Future<Either<Failure, List<FollowedNoteEntity>>> getAll() async {
    try {
      final models = await isar.followedNoteModels
          .filter()
          .removedAtIsNull()
          .sortByFollowedAtDesc()
          .findAll();
      final entities = <FollowedNoteEntity>[];
      for (final m in models) {
        entities.add(await _toEntity(m));
      }
      return Right(entities);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> followNote(
      String eventId, String contentPreview) async {
    try {
      // Reactivate an existing tombstone rather than short-circuit if the row
      // was previously unfollowed on this device — the user meant "follow again".
      final existing = await isar.followedNoteModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      if (existing != null && existing.removedAt == null) {
        return const Right(unit);
      }

      final model = (existing ?? FollowedNoteModel())
        ..eventId = eventId
        ..contentPreview = contentPreview
        ..followedAt = DateTime.now()
        ..removedAt = null;

      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.followedNote,
        dTag: eventId,
        content: FollowedNoteBody.forActive(model),
      );

      await isar.writeTxn(() async {
        await isar.followedNoteModels.put(model);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> unfollowNote(String eventId) async {
    try {
      final model = await isar.followedNoteModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      if (model == null || model.removedAt != null) return const Right(unit);

      // Undo semantics per plan §5a: keep the row, flip to tombstone state,
      // re-sign a fresh mesh event with a NEWER `created_at`.
      model.removedAt = DateTime.now();
      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.followedNote,
        dTag: eventId,
        content: FollowedNoteBody.forRemoved(model),
      );

      await isar.writeTxn(() async {
        await isar.followedNoteModels.put(model);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// "Mark all references as read" — deletes the unread rows for every child
  /// of [eventId]. Same UX as before (one-tap badge clear) but rebuilt on top
  /// of the same unread table the rest of the app uses.
  @override
  Future<Either<Failure, Unit>> clearNewReferences(String eventId) async {
    try {
      final childIds = await _childIdsOf(eventId);
      if (childIds.isEmpty) return const Right(unit);
      await isar.writeTxn(() async {
        await isar.unreadNoteModels
            .filter()
            .anyOf(childIds, (q, id) => q.eventIdEqualTo(id))
            .deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isFollowed(String eventId) async {
    try {
      final model = await isar.followedNoteModels
          .filter()
          .eventIdEqualTo(eventId)
          .removedAtIsNull()
          .findFirst();
      return Right(model != null);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Stream<bool> watchIsFollowed(String eventId) {
    return isar.followedNoteModels
        .filter()
        .eventIdEqualTo(eventId)
        .removedAtIsNull()
        .watch(fireImmediately: true)
        .map((rows) => rows.isNotEmpty);
  }
}
