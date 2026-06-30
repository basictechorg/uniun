import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/llm/inference_scheduler.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';
import 'package:uniun/domain/repositories/scheduler_coordinator.dart';

/// Adapts [InferenceScheduler.setForeground] to the domain-side
/// [SchedulerCoordinator] contract.
///
/// Stays thin on purpose: the data-layer scheduler is the source of truth;
/// the coordinator is just the layer-correct doorway for use cases / BLoCs
/// so they don't need to import `lib/data/`.
///
/// Cloud backend coordination (cancelling the OpenRouter SSE on chat
/// preempt) is intentionally not handled here — that path runs network-
/// concurrent and already has its own cancel-port in `RemoteLlmDataSource`.
@Injectable(as: SchedulerCoordinator)
class SchedulerCoordinatorImpl implements SchedulerCoordinator {
  final InferenceScheduler _scheduler;
  const SchedulerCoordinatorImpl(this._scheduler);

  @override
  Future<Either<Failure, Unit>> setForeground(LlmTaskKind? kind) async {
    try {
      _scheduler.setForeground(kind);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
