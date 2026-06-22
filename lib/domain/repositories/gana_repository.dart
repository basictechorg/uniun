import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';

abstract class GanaRepository {
  /// Insert if [GanaEntity.ganaId] is new, else update the existing row.
  /// Returns the persisted entity.
  Future<Either<Failure, GanaEntity>> upsertGana(GanaEntity gana);

  /// All Ganas, newest-updated first.
  Future<Either<Failure, List<GanaEntity>>> getGanas();

  /// Only enabled Ganas. Used by the engine on schedule rebuild.
  Future<Either<Failure, List<GanaEntity>>> getEnabledGanas();

  Future<Either<Failure, GanaEntity>> getGanaById(String ganaId);

  /// Deletes the Gana and all of its run-log rows in one txn.
  Future<Either<Failure, Unit>> deleteGana(String ganaId);

  Future<Either<Failure, Unit>> setEnabled(String ganaId, bool enabled);

  /// Persist the cursor advance from one successful run.
  Future<Either<Failure, Unit>> advanceCursor({
    required String ganaId,
    String? lastProcessedEventId,
    DateTime? lastProcessedCreated,
    required DateTime lastRunAt,
  });
}
