import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';

part 'gana_entity.freezed.dart';

@freezed
abstract class GanaEntity with _$GanaEntity {
  const factory GanaEntity({
    required String ganaId,
    required String name,
    @Default(<String>[]) List<String> manasIds,
    required String taskPrompt,

    // Input
    GanaInputType? inputType,
    String? inputRefId,

    // Output
    required GanaOutputType outputType,
    String? outputChannelId,
    String? outputGroupId,
    int? outputDmConversationId,

    // Model preference
    String? desiredModelId,

    // Triggers
    @Default(false) bool triggerReactive,
    int? triggerIntervalMinutes,
    @Default(GanaTriggerMode.recurring) GanaTriggerMode triggerMode,

    /// Required for recurring mode (1..1000). When set, the engine
    /// auto-disables the Gana once it has produced this many successful
    /// publishes. Null/ignored for one-shot.
    int? maxOutputs,

    // Master switch
    @Default(false) bool enabled,

    // Cursor
    String? lastProcessedEventId,
    DateTime? lastProcessedCreated,
    DateTime? lastRunAt,

    // Metadata
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _GanaEntity;
}
