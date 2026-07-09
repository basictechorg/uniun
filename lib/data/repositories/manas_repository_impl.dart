import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/repositories/manas_repository.dart';
import 'package:uniun/features/mesh/sync/bodies/manas_body.dart';
import 'package:uniun/features/mesh/sync/bodies/manas_member_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

@Injectable(as: ManasRepository)
class ManasRepositoryImpl extends ManasRepository {
  final Isar isar;
  final MeshEventSigner _signer;

  ManasRepositoryImpl({required this.isar, required MeshEventSigner signer})
      : _signer = signer;

  @override
  Future<Either<Failure, ManasEntity>> upsertManas(ManasEntity manas) async {
    try {
      final existing = await isar.manasModels
          .filter()
          .manasIdEqualTo(manas.manasId)
          .findFirst();

      final model = ManasModel()
        ..manasId = manas.manasId
        ..name = manas.name
        ..description = manas.description
        ..iconName = manas.iconName
        ..createdAt = manas.createdAt
        ..updatedAt = manas.updatedAt
        // Ressurection: re-signing as active clears any prior tombstone.
        ..removedAt = null;
      if (existing != null) model.id = existing.id;

      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.manas,
        dTag: manas.manasId,
        content: ManasBody.forActive(model),
      );

      await isar.writeTxn(() async {
        await isar.manasModels.put(model);
      });

      final count = await _countActiveLinks(manas.manasId);
      return Right(model.toDomain(noteCount: count));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ManasEntity>>> getManasList() async {
    try {
      final rows = await isar.manasModels
          .filter()
          .removedAtIsNull()
          .sortByUpdatedAtDesc()
          .findAll();
      final result = <ManasEntity>[];
      for (final m in rows) {
        final count = await _countActiveLinks(m.manasId);
        result.add(m.toDomain(noteCount: count));
      }
      return Right(result);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ManasEntity>> getManasById(String manasId) async {
    try {
      final row = await isar.manasModels
          .filter()
          .manasIdEqualTo(manasId)
          .and()
          .removedAtIsNull()
          .findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Manas not found'));
      }
      final count = await _countActiveLinks(manasId);
      return Right(row.toDomain(noteCount: count));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteManas(String manasId) async {
    try {
      final model = await isar.manasModels
          .filter()
          .manasIdEqualTo(manasId)
          .findFirst();
      if (model == null || model.removedAt != null) {
        return const Right(unit);
      }

      // Undo semantics per plan §5a: keep the row, flip to tombstone state,
      // re-sign a fresh mesh event with a NEWER `created_at`.
      model.removedAt = DateTime.now();
      model.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.manas,
        dTag: manasId,
        content: ManasBody.forRemoved(model),
      );

      // Tombstone every active membership edge as well so peers converge on
      // "Manas is gone" AND "no notes are members of it any more".
      final activeLinks = await isar.manasNoteLinkModels
          .filter()
          .manasIdEqualTo(manasId)
          .and()
          .removedAtIsNull()
          .findAll();
      final now = DateTime.now();
      for (final link in activeLinks) {
        link.removedAt = now;
        link.signedNostrEvent = await _signer.sign(
          kind: MeshEventKinds.manasMember,
          dTag: ManasMemberBody.buildDTag(link.manasId, link.noteId),
          content: ManasMemberBody.forRemoved(link),
        );
      }

      await isar.writeTxn(() async {
        await isar.manasModels.put(model);
        for (final link in activeLinks) {
          await isar.manasNoteLinkModels.put(link);
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> addNoteToManas(
      String manasId, String noteId) async {
    try {
      final existing = await isar.manasNoteLinkModels
          .filter()
          .manasIdEqualTo(manasId)
          .noteIdEqualTo(noteId)
          .findFirst();
      if (existing != null && existing.removedAt == null) {
        return const Right(unit);
      }

      final link = (existing ?? ManasNoteLinkModel())
        ..manasId = manasId
        ..noteId = noteId
        ..addedAt = DateTime.now()
        ..removedAt = null;

      link.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.manasMember,
        dTag: ManasMemberBody.buildDTag(manasId, noteId),
        content: ManasMemberBody.forActive(link),
      );

      await isar.writeTxn(() async {
        await isar.manasNoteLinkModels.put(link);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeNoteFromManas(
      String manasId, String noteId) async {
    try {
      final link = await isar.manasNoteLinkModels
          .filter()
          .manasIdEqualTo(manasId)
          .noteIdEqualTo(noteId)
          .findFirst();
      if (link == null || link.removedAt != null) return const Right(unit);

      // Undo semantics per plan §5a: keep the row, flip to tombstone state,
      // re-sign a fresh mesh event with a NEWER `created_at`.
      link.removedAt = DateTime.now();
      link.signedNostrEvent = await _signer.sign(
        kind: MeshEventKinds.manasMember,
        dTag: ManasMemberBody.buildDTag(manasId, noteId),
        content: ManasMemberBody.forRemoved(link),
      );

      await isar.writeTxn(() async {
        await isar.manasNoteLinkModels.put(link);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getNoteIdsForManas(
      String manasId) async {
    try {
      final links = await isar.manasNoteLinkModels
          .filter()
          .manasIdEqualTo(manasId)
          .and()
          .removedAtIsNull()
          .sortByAddedAt()
          .findAll();
      return Right(links.map((l) => l.noteId).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getManasIdsForNote(
      String noteId) async {
    try {
      final links = await isar.manasNoteLinkModels
          .filter()
          .noteIdEqualTo(noteId)
          .and()
          .removedAtIsNull()
          .findAll();
      return Right(links.map((l) => l.manasId).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<int> _countActiveLinks(String manasId) {
    return isar.manasNoteLinkModels
        .filter()
        .manasIdEqualTo(manasId)
        .and()
        .removedAtIsNull()
        .count();
  }
}
