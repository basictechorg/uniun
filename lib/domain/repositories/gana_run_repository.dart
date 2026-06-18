import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';

abstract class GanaRunRepository {
  /// Insert a new run log row.
  Future<Either<Failure, Unit>> logRun(GanaRunEntity run);

  /// Last [limit] runs for a Gana, newest first.
  Future<Either<Failure, List<GanaRunEntity>>> getRunsFor(
    String ganaId, {
    int limit = 10,
  });

  /// All output event ids this Gana ever produced — used by the engine's
  /// self-loop guard when filtering input.
  Future<Either<Failure, Set<String>>> getOutputEventIdsFor(String ganaId);

  /// Trim run logs per the retention policy (keep last [keepPerGana] per
  /// Gana, hard cap [globalCap] total). Idempotent.
  Future<Either<Failure, Unit>> pruneOldRuns({
    int keepPerGana = 10,
    int globalCap = 1000,
  });
}
