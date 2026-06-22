import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';
import 'package:uniun/domain/repositories/gana_repository.dart';
import 'package:uniun/domain/repositories/gana_run_repository.dart';

/// Inputs for use cases whose record type would otherwise leak through the
/// `UseCase<T,P>` signature.

class GanaToggleInput {
  final String ganaId;
  final bool enabled;
  const GanaToggleInput(this.ganaId, this.enabled);
}

class GanaCursorAdvanceInput {
  final String ganaId;
  final String? lastProcessedEventId;
  final DateTime? lastProcessedCreated;
  final DateTime lastRunAt;
  const GanaCursorAdvanceInput({
    required this.ganaId,
    this.lastProcessedEventId,
    this.lastProcessedCreated,
    required this.lastRunAt,
  });
}

// ── Gana CRUD ────────────────────────────────────────────────────────────

@lazySingleton
class UpsertGanaUseCase
    extends UseCase<Either<Failure, GanaEntity>, GanaEntity> {
  final GanaRepository repository;
  UpsertGanaUseCase(this.repository);

  @override
  Future<Either<Failure, GanaEntity>> call(GanaEntity input,
          {bool cached = false}) =>
      repository.upsertGana(input);
}

@lazySingleton
class GetGanasUseCase
    extends NoParamsUseCase<Either<Failure, List<GanaEntity>>> {
  final GanaRepository repository;
  GetGanasUseCase(this.repository);

  @override
  Future<Either<Failure, List<GanaEntity>>> call() => repository.getGanas();
}

@lazySingleton
class GetEnabledGanasUseCase
    extends NoParamsUseCase<Either<Failure, List<GanaEntity>>> {
  final GanaRepository repository;
  GetEnabledGanasUseCase(this.repository);

  @override
  Future<Either<Failure, List<GanaEntity>>> call() =>
      repository.getEnabledGanas();
}

@lazySingleton
class GetGanaByIdUseCase extends UseCase<Either<Failure, GanaEntity>, String> {
  final GanaRepository repository;
  GetGanaByIdUseCase(this.repository);

  @override
  Future<Either<Failure, GanaEntity>> call(String ganaId,
          {bool cached = false}) =>
      repository.getGanaById(ganaId);
}

@lazySingleton
class DeleteGanaUseCase extends UseCase<Either<Failure, Unit>, String> {
  final GanaRepository repository;
  DeleteGanaUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String ganaId, {bool cached = false}) =>
      repository.deleteGana(ganaId);
}

@lazySingleton
class SetGanaEnabledUseCase
    extends UseCase<Either<Failure, Unit>, GanaToggleInput> {
  final GanaRepository repository;
  SetGanaEnabledUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(GanaToggleInput input,
          {bool cached = false}) =>
      repository.setEnabled(input.ganaId, input.enabled);
}

@lazySingleton
class AdvanceGanaCursorUseCase
    extends UseCase<Either<Failure, Unit>, GanaCursorAdvanceInput> {
  final GanaRepository repository;
  AdvanceGanaCursorUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(GanaCursorAdvanceInput input,
          {bool cached = false}) =>
      repository.advanceCursor(
        ganaId: input.ganaId,
        lastProcessedEventId: input.lastProcessedEventId,
        lastProcessedCreated: input.lastProcessedCreated,
        lastRunAt: input.lastRunAt,
      );
}

// ── Gana run log ─────────────────────────────────────────────────────────

@lazySingleton
class LogGanaRunUseCase
    extends UseCase<Either<Failure, Unit>, GanaRunEntity> {
  final GanaRunRepository repository;
  LogGanaRunUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(GanaRunEntity input,
          {bool cached = false}) =>
      repository.logRun(input);
}

@lazySingleton
class GetGanaRunsUseCase
    extends UseCase<Either<Failure, List<GanaRunEntity>>, String> {
  final GanaRunRepository repository;
  GetGanaRunsUseCase(this.repository);

  @override
  Future<Either<Failure, List<GanaRunEntity>>> call(String ganaId,
          {bool cached = false}) =>
      repository.getRunsFor(ganaId);
}

@lazySingleton
class GetGanaOutputEventIdsUseCase
    extends UseCase<Either<Failure, Set<String>>, String> {
  final GanaRunRepository repository;
  GetGanaOutputEventIdsUseCase(this.repository);

  @override
  Future<Either<Failure, Set<String>>> call(String ganaId,
          {bool cached = false}) =>
      repository.getOutputEventIdsFor(ganaId);
}

@lazySingleton
class PruneGanaRunsUseCase
    extends NoParamsUseCase<Either<Failure, Unit>> {
  final GanaRunRepository repository;
  PruneGanaRunsUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call() => repository.pruneOldRuns();
}
