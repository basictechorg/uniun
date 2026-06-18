import 'package:flutter/widgets.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uniun/data/datasources/isar_schemas.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:workmanager/workmanager.dart';

/// Background task name. Must match `BGTaskSchedulerPermittedIdentifiers`
/// in `ios/Runner/Info.plist`. Android only requires the constant to be
/// stable across schedules.
const String kGanaBackgroundTickTask = 'in.uniun.app.gana.tick';

/// Hard wall-clock cap per background run. iOS gives a few seconds for
/// `BGProcessingTask` if `requiresExternalPower` is false; Android's
/// foreground service can run longer but we don't need it to. Bail early
/// rather than fight the OS.
const Duration kBackgroundRunBudget = Duration(seconds: 25);

/// Minimum interval between background ticks regardless of per-Gana
/// trigger config (Battery / fairness clamp from `ganas.md` §2.4.3).
const Duration kBackgroundMinInterval = Duration(minutes: 30);

/// WorkManager dispatcher — top-level function MUST be top-level (not a
/// class method) because the plugin tears off its reference.
///
/// ## What this does NOT do
///
/// - It does NOT run inference. flutter_gemma 0.16.5 is unverified in a
///   background isolate (see plan §6a). When inference is needed in true
///   background, we'd need to either:
///     a. Verify flutter_gemma supports `BackgroundIsolateBinaryMessenger`
///        and call it from this isolate, OR
///     b. Surface the queued work back to the main isolate on next foreground.
///   For v1 we take path (b): the engine isolate writes work into Isar
///   normally and the WorkManager tick just bumps cursors / triggers
///   timestamps so interval Ganas don't drift wildly while the app sleeps.
///
/// - It does NOT publish events. Same reason: NIP-17 / MLS publishing
///   touches native plugins that aren't safe to use without a fully
///   initialized Flutter engine.
///
/// ## What it DOES
///
/// Opens its own Isar handle and walks all enabled interval Ganas whose
/// `lastRunAt + intervalMinutes < now`. For each, stamps a "due" marker
/// (sets `lastRunAt = now`) so that when the user reopens the app, the
/// engine's `_maybeRunInterval` immediately picks them up. Plain cursor
/// bookkeeping — cheap, deterministic, no inference cost.
@pragma('vm:entry-point')
void ganaWorkManagerDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != kGanaBackgroundTickTask) return true;

    // workmanager's executeTask runs in a fresh isolate; ensure the
    // binding is up so plugin channels (path_provider) work.
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final isar = await Isar.open(
        isarSchemas,
        directory: dir.path,
        name: Isar.defaultName,
      );

      final budgetEnd = DateTime.now().add(kBackgroundRunBudget);

      // Walk enabled interval Ganas. For each one whose interval is due,
      // bump `lastRunAt` so when the app reopens, the engine sees a fresh
      // schedule and the user can intervene before the next inference fires.
      final ganas = await isar.ganaModels
          .filter()
          .enabledEqualTo(true)
          .findAll();

      for (final g in ganas) {
        if (DateTime.now().isAfter(budgetEnd)) {
          debugPrint('Gana bg tick: budget exhausted, bailing');
          break;
        }
        final mins = g.triggerIntervalMinutes;
        if (mins == null || mins <= 0) continue;
        // Battery clamp — bg ticks treat the interval as at least
        // [kBackgroundMinInterval] regardless of user setting.
        final effective =
            Duration(minutes: mins) < kBackgroundMinInterval
                ? kBackgroundMinInterval
                : Duration(minutes: mins);
        final last = g.lastRunAt;
        if (last != null && DateTime.now().difference(last) < effective) {
          continue;
        }
        // Stamp lastRunAt so the foreground engine's next schedule rebuild
        // picks it up as "due" and runs immediately when the app opens.
        g.lastRunAt = DateTime.now();
        await isar.writeTxn(() async {
          await isar.ganaModels.put(g);
        });
      }
      await isar.close();
      return true;
    } catch (e, st) {
      debugPrint('Gana bg tick failed: $e\n$st');
      return false; // workmanager will retry on next schedule
    }
  });
}

