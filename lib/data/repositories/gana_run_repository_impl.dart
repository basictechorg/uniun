import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';
import 'package:uniun/domain/repositories/gana_run_repository.dart';

@Injectable(as: GanaRunRepository)
class GanaRunRepositoryImpl extends GanaRunRepository {
  final Isar isar;

  GanaRunRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, Unit>> logRun(GanaRunEntity r) async {
    try {
      final row = GanaRunModel()
        ..runId = r.runId
        ..ganaId = r.ganaId
        ..startedAt = r.startedAt
        ..status = r.status
        ..skipReason = r.skipReason
        ..inputEventIds = r.inputEventIds
        ..outputEventId = r.outputEventId
        ..error = r.error;
      await isar.writeTxn(() async {
        await isar.ganaRunModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GanaRunEntity>>> getRunsFor(
    String ganaId, {
    int limit = 10,
  }) async {
    try {
      final rows = await isar.ganaRunModels
          .filter()
          .ganaIdEqualTo(ganaId)
          .sortByStartedAtDesc()
          .limit(limit)
          .findAll();
      return Right(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getOutputEventIdsFor(
      String ganaId) async {
    try {
      final rows = await isar.ganaRunModels
          .filter()
          .ganaIdEqualTo(ganaId)
          .outputEventIdIsNotNull()
          .outputEventIdProperty()
          .findAll();
      // Property query returns non-null values per the filter, so the cast is
      // safe.
      return Right(rows.cast<String>().toSet());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> pruneOldRuns({
    int keepPerGana = 10,
    int globalCap = 1000,
  }) async {
    try {
      // Per-Gana trim: for each ganaId, keep newest [keepPerGana], delete rest.
      final allGanaIds = await isar.ganaRunModels
          .where()
          .ganaIdProperty()
          .findAll();
      final uniqueIds = allGanaIds.toSet();
      await isar.writeTxn(() async {
        for (final gid in uniqueIds) {
          final keep = await isar.ganaRunModels
              .filter()
              .ganaIdEqualTo(gid)
              .sortByStartedAtDesc()
              .limit(keepPerGana)
              .idProperty()
              .findAll();
          final keepSet = keep.toSet();
          final victims = await isar.ganaRunModels
              .filter()
              .ganaIdEqualTo(gid)
              .idProperty()
              .findAll();
          final toDelete = victims.where((i) => !keepSet.contains(i)).toList();
          if (toDelete.isNotEmpty) {
            await isar.ganaRunModels.deleteAll(toDelete);
          }
        }

        // Global cap fallback — if per-Gana trim still leaves more than
        // [globalCap], delete the oldest rows beyond the cap.
        final total = await isar.ganaRunModels.count();
        if (total > globalCap) {
          final overflow = await isar.ganaRunModels
              .where()
              .sortByStartedAt()
              .limit(total - globalCap)
              .idProperty()
              .findAll();
          await isar.ganaRunModels.deleteAll(overflow);
        }
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
