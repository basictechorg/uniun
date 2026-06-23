import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/repositories/gana_repository.dart';

@Injectable(as: GanaRepository)
class GanaRepositoryImpl extends GanaRepository {
  final Isar isar;

  GanaRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, GanaEntity>> upsertGana(GanaEntity g) async {
    try {
      final existing =
          await isar.ganaModels.filter().ganaIdEqualTo(g.ganaId).findFirst();

      final model = GanaModel()
        ..ganaId = g.ganaId
        ..name = g.name
        ..manasIds = g.manasIds
        ..taskPrompt = g.taskPrompt
        ..inputType = g.inputType
        ..inputRefId = g.inputRefId
        ..outputType = g.outputType
        ..outputChannelId = g.outputChannelId
        ..outputGroupId = g.outputGroupId
        ..outputDmConversationId = g.outputDmConversationId
        ..desiredModelId = g.desiredModelId
        ..triggerReactive = g.triggerReactive
        ..triggerIntervalMinutes = g.triggerIntervalMinutes
        ..triggerMode = g.triggerMode
        ..maxOutputs = g.maxOutputs
        ..enabled = g.enabled
        ..lastProcessedEventId = g.lastProcessedEventId
        ..lastProcessedCreated = g.lastProcessedCreated
        ..lastRunAt = g.lastRunAt
        ..createdAt = g.createdAt
        ..updatedAt = g.updatedAt;

      await isar.writeTxn(() async {
        if (existing != null) model.id = existing.id;
        await isar.ganaModels.put(model);
      });

      return Right(model.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GanaEntity>>> getGanas() async {
    try {
      final rows =
          await isar.ganaModels.where().sortByUpdatedAtDesc().findAll();
      return Right(rows.map((m) => m.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GanaEntity>>> getEnabledGanas() async {
    try {
      final rows = await isar.ganaModels
          .filter()
          .enabledEqualTo(true)
          .sortByUpdatedAtDesc()
          .findAll();
      return Right(rows.map((m) => m.toDomain()).toList());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GanaEntity>> getGanaById(String ganaId) async {
    try {
      final row =
          await isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Gana not found'));
      }
      return Right(row.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteGana(String ganaId) async {
    try {
      await isar.writeTxn(() async {
        await isar.ganaModels.filter().ganaIdEqualTo(ganaId).deleteAll();
        await isar.ganaRunModels.filter().ganaIdEqualTo(ganaId).deleteAll();
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setEnabled(String ganaId, bool enabled) async {
    try {
      final row =
          await isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Gana not found'));
      }
      row
        ..enabled = enabled
        ..updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.ganaModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> advanceCursor({
    required String ganaId,
    String? lastProcessedEventId,
    DateTime? lastProcessedCreated,
    required DateTime lastRunAt,
  }) async {
    try {
      final row =
          await isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
      if (row == null) {
        return const Left(Failure.notFoundFailure('Gana not found'));
      }
      // Only advance the input cursor when caller supplied a value — interval
      // standalone Ganas advance only `lastRunAt`.
      if (lastProcessedEventId != null) {
        row.lastProcessedEventId = lastProcessedEventId;
      }
      if (lastProcessedCreated != null) {
        row.lastProcessedCreated = lastProcessedCreated;
      }
      row.lastRunAt = lastRunAt;
      await isar.writeTxn(() async {
        await isar.ganaModels.put(row);
      });
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
