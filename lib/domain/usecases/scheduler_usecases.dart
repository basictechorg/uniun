import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';
import 'package:uniun/domain/repositories/scheduler_coordinator.dart';

/// Sets the foreground LLM task kind on the scheduler, hoisting matching
/// queued/running jobs to T1 (foreground tier). Pass `null` on dispose to
/// clear.
///
/// Replaces the prior `PreemptBackgroundWorkUseCase` /
/// `ResumeBackgroundWorkUseCase` pair for the scheduler-managed surfaces
/// (Shiv chat, NatarajDeck, GanaForm preview). See
/// `docs/SHIVA/scheduling.md` §3 for tier semantics.
@lazySingleton
class SetForegroundKindUseCase
    extends UseCase<Either<Failure, Unit>, LlmTaskKind?> {
  final SchedulerCoordinator _coordinator;
  const SetForegroundKindUseCase(this._coordinator);

  @override
  Future<Either<Failure, Unit>> call(
    LlmTaskKind? kind, {
    bool cached = false,
  }) =>
      _coordinator.setForeground(kind);
}
