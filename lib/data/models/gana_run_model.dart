import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/domain/entities/gana/gana_run_entity.dart';

part 'gana_run_model.g.dart';

/// Per-Gana run log. Best-effort: rows are pruned by `CleanupManager`
/// (keep last 10 per Gana, hard cap ~1000 globally). Also used as the
/// self-loop guard source — the engine drops any input note whose id is
/// present as an `outputEventId` on this Gana's run history.
@Collection(ignore: {'copyWith'})
@Name('GanaRun')
class GanaRunModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String runId;

  @Index()
  late String ganaId;

  @Index()
  late DateTime startedAt;

  @Enumerated(EnumType.name)
  late GanaRunStatus status;

  /// Why the run was skipped (only set when [status] == skipped).
  @Enumerated(EnumType.name)
  GanaSkipReason? skipReason;

  /// Input event ids consumed during the run. May be empty for standalone
  /// (interval) Ganas where there is no input surface.
  List<String> inputEventIds = const [];

  /// Event id of the published output. Null for non-succeeded runs.
  String? outputEventId;

  /// Error message for [GanaRunStatus.failed]. Null otherwise.
  String? error;
}

extension GanaRunModelExtension on GanaRunModel {
  GanaRunEntity toDomain() => GanaRunEntity(
        runId: runId,
        ganaId: ganaId,
        startedAt: startedAt,
        status: status,
        skipReason: skipReason,
        inputEventIds: inputEventIds,
        outputEventId: outputEventId,
        error: error,
      );
}
