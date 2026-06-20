import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';

part 'gana_model.g.dart';

/// A user-defined AI worker. See `ganas.md` (repo root) for the full model.
///
/// Local-only config — never broadcast as a Nostr event. Two devices owned by
/// the same user have independent Gana sets until/unless a private-config
/// sync layer is added (out of scope for v1).
@Collection(ignore: {'copyWith'})
@Name('Gana')
class GanaModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String ganaId;

  late String name;
  String? description;

  /// One or more Manases backing the Gana's knowledge. Set semantics —
  /// duplicates are dedup'd by the engine before context packing. Stored as
  /// a free list because Isar does not support set columns.
  List<String> manasIds = const [];

  /// User-authored instructions injected into every prompt.
  late String taskPrompt;

  // ── Input ────────────────────────────────────────────────────────────────

  /// Null ⇒ standalone (no input fetch — interval-only Gana).
  @Enumerated(EnumType.name)
  GanaInputType? inputType;

  /// Type-dependent reference id. See [GanaInputType] for what each holds.
  /// - channel: hex channel id (kind-40 event id)
  /// - privateChannel: groupId
  /// - dm: stringified `DmConversationModel.id` (Isar Id)
  /// - user: pubkey hex
  /// - followedNote: event id of the followed note
  String? inputRefId;

  // ── Output ───────────────────────────────────────────────────────────────

  @Enumerated(EnumType.name)
  late GanaOutputType outputType;

  /// Public channel id when [outputType] == channel.
  String? outputChannelId;

  /// Group id when [outputType] == privateChannel.
  String? outputGroupId;

  /// `DmConversationModel.id` when [outputType] == dm. Plain `int?`, not
  /// `Id?` — `Id` is reserved for the primary key of THIS collection.
  int? outputDmConversationId;

  // ── Model preference ─────────────────────────────────────────────────────

  /// Per-Gana preferred model. `null` ⇒ "use whichever model is active."
  /// When set and the active model id doesn't match, the run is logged as
  /// `skipped: modelMismatch` and the cursor is NOT advanced.
  String? desiredModelId;

  // ── Triggers ─────────────────────────────────────────────────────────────

  bool triggerReactive = false;

  /// Null ⇒ no interval trigger. Form clamps to ≥5 minutes; background
  /// execution further clamps to ≥30 minutes regardless of this value.
  int? triggerIntervalMinutes;

  /// How the Gana fires. Recurring = cron-job behaviour (default).
  /// One-shot = auto-disable after the first successful run.
  /// Defaults to recurring on legacy rows.
  @Enumerated(EnumType.name)
  GanaTriggerMode triggerMode = GanaTriggerMode.recurring;

  // ── Master switch ────────────────────────────────────────────────────────

  /// Defaults to `false`. The user explicitly enables after reviewing the
  /// config — prevents accidental publishing on save.
  bool enabled = false;

  // ── Cursor ───────────────────────────────────────────────────────────────

  /// Last input event id the engine consumed — used as a same-second
  /// tiebreak in the input filter.
  String? lastProcessedEventId;

  /// Monotonic "new since" cursor — most input filters select rows with
  /// `created > lastProcessedCreated`.
  DateTime? lastProcessedCreated;

  /// Anchor for interval triggers — prevents double-fires on app relaunch.
  DateTime? lastRunAt;

  // ── Metadata ─────────────────────────────────────────────────────────────

  late DateTime createdAt;
  late DateTime updatedAt;
}

extension GanaModelExtension on GanaModel {
  GanaEntity toDomain() => GanaEntity(
        ganaId: ganaId,
        name: name,
        description: description,
        manasIds: manasIds,
        taskPrompt: taskPrompt,
        inputType: inputType,
        inputRefId: inputRefId,
        outputType: outputType,
        outputChannelId: outputChannelId,
        outputGroupId: outputGroupId,
        outputDmConversationId: outputDmConversationId,
        desiredModelId: desiredModelId,
        triggerReactive: triggerReactive,
        triggerIntervalMinutes: triggerIntervalMinutes,
        triggerMode: triggerMode,
        enabled: enabled,
        lastProcessedEventId: lastProcessedEventId,
        lastProcessedCreated: lastProcessedCreated,
        lastRunAt: lastRunAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
