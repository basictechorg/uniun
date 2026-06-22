import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';

/// A user-facing trigger preset. Each preset folds the raw `(triggerMode,
/// triggerReactive, triggerIntervalMinutes)` triple into a single choice
/// — users pick one of these instead of reasoning about all three knobs.
///
/// Not persisted. Derived from the raw fields by [fromFields]; applied to
/// the raw fields by the form bloc when the user picks a preset.
enum GanaTriggerPreset {
  /// One-shot, standalone: fires once when the Gana is enabled.
  /// Raw: mode=oneShot, reactive=false, interval=null.
  onceOnEnable,

  /// One-shot with an input source: fires once on the first new message,
  /// then auto-disables. Raw: mode=oneShot, reactive=true, interval=null.
  onceOnFirstMessage,

  /// Recurring + reactive (no interval): fires within seconds of every new
  /// message on the input source. Raw: mode=recurring, reactive=true,
  /// interval=null. Requires an input source.
  everyMessage,

  /// Recurring + interval (no reactive): cron-style fires every N minutes.
  /// Raw: mode=recurring, reactive=false, interval=N. Works with or
  /// without an input source.
  onSchedule,

  /// Recurring + reactive + interval: fires on every new message AND on
  /// the timer (whichever comes first). Requires an input source.
  /// Raw: mode=recurring, reactive=true, interval=N.
  messageOrSchedule;

  /// Derive a preset from the raw trigger fields. Returns `null` if the
  /// combination doesn't map to any preset (legacy / mid-edit state).
  static GanaTriggerPreset? fromFields({
    required GanaTriggerMode mode,
    required bool reactive,
    required int? intervalMinutes,
    required GanaInputType? inputType,
  }) {
    final hasInput = inputType != null;
    final hasInterval = intervalMinutes != null && intervalMinutes >= 1;
    if (mode == GanaTriggerMode.oneShot) {
      if (!hasInput && !reactive) return GanaTriggerPreset.onceOnEnable;
      if (hasInput && reactive) return GanaTriggerPreset.onceOnFirstMessage;
      return null;
    }
    if (reactive && !hasInterval) return GanaTriggerPreset.everyMessage;
    if (!reactive && hasInterval) return GanaTriggerPreset.onSchedule;
    if (reactive && hasInterval) return GanaTriggerPreset.messageOrSchedule;
    return null;
  }

  /// Presets valid for the given input-type. Hides options that can't
  /// fire (e.g. "every message" with no input source).
  static List<GanaTriggerPreset> validFor(GanaInputType? inputType) {
    if (inputType == null) {
      return const [
        GanaTriggerPreset.onceOnEnable,
        GanaTriggerPreset.onSchedule,
      ];
    }
    return const [
      GanaTriggerPreset.onceOnFirstMessage,
      GanaTriggerPreset.everyMessage,
      GanaTriggerPreset.onSchedule,
      GanaTriggerPreset.messageOrSchedule,
    ];
  }
}
