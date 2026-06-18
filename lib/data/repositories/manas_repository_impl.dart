import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/repositories/manas_repository.dart';

@Injectable(as: ManasRepository)
class ManasRepositoryImpl extends ManasRepository {
  final Isar isar;

  ManasRepositoryImpl({required this.isar});

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
        ..updatedAt = manas.updatedAt;

      await isar.writeTxn(() async {
        if (existing != null) model.id = existing.id;
        await isar.manasModels.put(model);
      });

      final count = await _countLinks(manas.manasId);
      return Right(model.toDomain(noteCount: count));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ManasEntity>>> getManasList() async {
    try {
      final rows = await isar.manasModels
          .where()
          .sortByUpdatedAtDesc()
          .findAll();
      final result = <ManasEntity>[];
      for (final m in rows) {
        final count = await _countLinks(m.manasId);
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
      final row =
          await isar.manasModels.filter().manasIdEqualTo(manasId).findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Manas not found'));
      }
      final count = await _countLinks(manasId);
      return Right(row.toDomain(noteCount: count));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteManas(String manasId) async {
    try {
      await isar.writeTxn(() async {
        await isar.manasModels.filter().manasIdEqualTo(manasId).deleteAll();
        await isar.manasNoteLinkModels
            .filter()
            .manasIdEqualTo(manasId)
            .deleteAll();
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
      if (existing != null) return const Right(unit);

      final link = ManasNoteLinkModel()
        ..manasId = manasId
        ..noteId = noteId
        ..addedAt = DateTime.now();

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
      await isar.writeTxn(() async {
        await isar.manasNoteLinkModels
            .filter()
            .manasIdEqualTo(manasId)
            .noteIdEqualTo(noteId)
            .deleteAll();
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
          .findAll();
      return Right(links.map((l) => l.manasId).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<int> _countLinks(String manasId) {
    return isar.manasNoteLinkModels
        .filter()
        .manasIdEqualTo(manasId)
        .count();
  }
}
