import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';

/// Domain contract for telling the on-device LLM scheduler which surface is
/// currently foreground.
///
/// Pages (ShivPage / NatarajDeckPage / GanaFormPage / note detail when an
/// extract is in flight) call this on `initState` / `dispose` via the
/// matching use case. The scheduler uses the foreground kind to hoist
/// matching tasks to T1 (foreground tier), preempting whatever lower-tier
/// job is running at the next token boundary.
///
/// `kind == null` means "no AI surface is foreground" — the scheduler
/// reverts to the regular tier order (T0 chat / T2 extract / T3 deadline /
/// T4 fair pool).
///
/// Cloud backend: this is a no-op. The cloud path is network-concurrent and
/// does not need scheduling — its own extraction cancel-port handles chat
/// preemption.
abstract class SchedulerCoordinator {
  Future<Either<Failure, Unit>> setForeground(LlmTaskKind? kind);
}
