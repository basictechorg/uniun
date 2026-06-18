import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/gana_run_status.dart';

part 'gana_run_entity.freezed.dart';

@freezed
abstract class GanaRunEntity with _$GanaRunEntity {
  const factory GanaRunEntity({
    required String runId,
    required String ganaId,
    required DateTime startedAt,
    required GanaRunStatus status,
    GanaSkipReason? skipReason,
    @Default(<String>[]) List<String> inputEventIds,
    String? outputEventId,
    String? error,
  }) = _GanaRunEntity;
}
