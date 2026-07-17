import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/enum/gana_trigger_preset.dart';

/// Covers: the full (mode, reactive, interval, input) → preset matrix,
/// unmappable legacy combinations, and per-input-type preset visibility.
void main() {
  GanaTriggerPreset? derive({
    GanaTriggerMode mode = GanaTriggerMode.recurring,
    bool reactive = false,
    int? interval,
    GanaInputType? input,
  }) =>
      GanaTriggerPreset.fromFields(
        mode: mode,
        reactive: reactive,
        intervalMinutes: interval,
        inputType: input,
      );

  group('fromFields', () {
    test('one-shot, no input, not reactive → onceOnEnable', () {
      expect(derive(mode: GanaTriggerMode.oneShot),
          GanaTriggerPreset.onceOnEnable);
    });

    test('one-shot, input + reactive → onceOnFirstMessage', () {
      expect(
          derive(
              mode: GanaTriggerMode.oneShot,
              reactive: true,
              input: GanaInputType.group),
          GanaTriggerPreset.onceOnFirstMessage);
    });

    test('one-shot mixed combos do not map (mid-edit / legacy)', () {
      // Input source but not reactive.
      expect(
          derive(mode: GanaTriggerMode.oneShot, input: GanaInputType.dm),
          isNull);
      // Reactive but no input source.
      expect(derive(mode: GanaTriggerMode.oneShot, reactive: true), isNull);
    });

    test('recurring + reactive, no interval → everyMessage', () {
      expect(derive(reactive: true, input: GanaInputType.group),
          GanaTriggerPreset.everyMessage);
    });

    test('recurring + interval, not reactive → onSchedule', () {
      expect(derive(interval: 30), GanaTriggerPreset.onSchedule);
    });

    test('recurring + reactive + interval → messageOrSchedule', () {
      expect(derive(reactive: true, interval: 60, input: GanaInputType.user),
          GanaTriggerPreset.messageOrSchedule);
    });

    test('recurring with neither reactive nor interval does not map', () {
      expect(derive(), isNull);
    });

    test('interval below 1 minute counts as no interval', () {
      expect(derive(interval: 0), isNull);
      expect(derive(reactive: true, interval: 0, input: GanaInputType.group),
          GanaTriggerPreset.everyMessage);
    });
  });

  group('validFor', () {
    test('standalone Gana (no input) only gets non-message presets', () {
      expect(GanaTriggerPreset.validFor(null), const [
        GanaTriggerPreset.onceOnEnable,
        GanaTriggerPreset.onSchedule,
      ]);
    });

    test('every input type gets the message-driven presets', () {
      for (final input in GanaInputType.values) {
        expect(
          GanaTriggerPreset.validFor(input),
          const [
            GanaTriggerPreset.onceOnFirstMessage,
            GanaTriggerPreset.everyMessage,
            GanaTriggerPreset.onSchedule,
            GanaTriggerPreset.messageOrSchedule,
          ],
          reason: 'input $input',
        );
      }
    });
  });
}
