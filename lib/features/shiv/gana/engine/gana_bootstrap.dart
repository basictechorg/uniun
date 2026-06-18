import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/features/shiv/gana/engine/gana_init_message.dart';
import 'package:uniun/features/shiv/gana/engine/gana_isolate.dart';
import 'package:uniun/features/shiv/gana/engine/gana_workmanager.dart';
import 'package:uniun/features/shiv/gana/inference/gana_inference_server.dart';
import 'package:workmanager/workmanager.dart';

/// Spawns the Gana engine isolate + initializes WorkManager. Idempotent.
///
/// Call from `_HomePageState.initState()` right after the gateway boot.
/// Lifecycle wiring (`paused`/`resumed`) is exposed via [scheduleBackground]
/// and [cancelBackground]; HomePage's `AppLifecycleState` listener invokes
/// them on transitions.
class GanaBootstrap {
  static bool _started = false;

  /// Unique name for the background tick. Stays constant across
  /// reschedules so iOS/Android dedup correctly.
  static const String _tickUniqueName = 'in.uniun.app.gana.tick.uniq';

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    final dir = await getApplicationDocumentsDirectory();

    // Resolve the active user's pubkey here in the main isolate —
    // FlutterSecureStorage and SharedPreferences are unavailable in
    // background isolates. Null is OK: the engine simply does nothing
    // until a user logs in (and on next launch the bootstrap re-runs).
    final keys = await getIt<UserRepository>().getActiveKeysHex();

    // Boot the main-isolate inference server FIRST so its SendPort exists
    // when we spawn the engine.
    final server = getIt<GanaInferenceServer>();
    await server.start();

    // Initialize workmanager. The dispatcher is a top-level Dart function
    // — see `gana_workmanager.dart`. We pass `isInDebugMode: false` to
    // suppress its on-device debug notifications; logs go through
    // `debugPrint` regardless.
    try {
      await Workmanager().initialize(
        ganaWorkManagerDispatcher,
        isInDebugMode: false,
      );
    } catch (e, st) {
      // Non-fatal — foreground engine still works without it.
      debugPrint('Workmanager.initialize failed (bg ticks disabled): $e\n$st');
    }

    try {
      await Isolate.spawn(
        ganaEntryPoint,
        GanaInitMessage(
          isarDirectory: dir.path,
          selfPubkeyHex: keys?.pubkeyHex,
          mainInferencePort: server.sendPort,
        ),
      );
    } catch (e, st) {
      _started = false; // allow retry
      debugPrint('GanaBootstrap.start failed: $e\n$st');
      rethrow;
    }
  }

  /// Schedule a background tick. Call on `AppLifecycleState.paused`. The
  /// OS will fire `ganaWorkManagerDispatcher` once within roughly
  /// [kBackgroundMinInterval] depending on system load and battery state.
  ///
  /// The actual run is a no-inference cursor refresh — see
  /// `gana_workmanager.dart` for what it does and doesn't do.
  static Future<void> scheduleBackground() async {
    try {
      await Workmanager().registerOneOffTask(
        _tickUniqueName,
        kGanaBackgroundTickTask,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        initialDelay: kBackgroundMinInterval,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } catch (e) {
      debugPrint('GanaBootstrap.scheduleBackground failed: $e');
    }
  }

  /// Cancel any pending background tick. Call on
  /// `AppLifecycleState.resumed` — the foreground engine takes over.
  static Future<void> cancelBackground() async {
    try {
      await Workmanager().cancelByUniqueName(_tickUniqueName);
    } catch (e) {
      debugPrint('GanaBootstrap.cancelBackground failed: $e');
    }
  }
}
