import 'package:flutter/foundation.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/features/shiv/gana/engine/gana_workmanager.dart';
import 'package:workmanager/workmanager.dart';

/// Wires up the WorkManager background-tick path for Ganas.
///
/// The foreground engine ([GanaEngine]) is a main-isolate `@lazySingleton`
/// — no separate isolate any more. This bootstrap handles ONLY the
/// OS-dispatched background tick (when the app is paused or killed),
/// which runs in its own ephemeral isolate spawned by WorkManager.
class GanaWorkmanagerBootstrap {
  static bool _initialized = false;

  /// Unique name for the background tick. Stays constant across
  /// reschedules so iOS/Android dedup correctly.
  static const String _tickUniqueName = 'in.uniun.app.gana.tick.uniq';

  /// One-time WorkManager initialization. Safe to call repeatedly.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // workmanager 0.9 dropped `isInDebugMode` (it was a no-op anyway —
      // logging now flows through WorkmanagerDebug handlers).
      await Workmanager().initialize(ganaWorkManagerDispatcher);
    } catch (e, st) {
      debugPrint(
          'GanaWorkmanagerBootstrap.initialize failed (bg ticks disabled): '
          '$e\n$st');
    }
  }

  /// Schedule a single bg tick. Call on `AppLifecycleState.paused`.
  static Future<void> scheduleBackground() async {
    try {
      // Resolve the active user's keys + cached UNIUN Cloud API key here in
      // the main isolate — FlutterSecureStorage isn't available in the
      // workmanager dispatcher isolate, so we hand them off via `inputData`.
      // The API key is already minted (foreground connect flow); the bg
      // isolate never re-authenticates, it just uses this copy.
      final keys = await getIt<UserRepository>().getActiveKeysHex();
      final uniunApiKey =
          await getIt<LlmCredentialsDataSource>().getUniunApiKey();
      await Workmanager().registerOneOffTask(
        _tickUniqueName,
        kGanaBackgroundTickTask,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        initialDelay: kBackgroundInitialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        inputData: {
          if (keys?.pubkeyHex != null) 'selfPubkeyHex': keys!.pubkeyHex,
          if (keys?.privkeyHex != null) 'privkeyHex': keys!.privkeyHex,
          if (uniunApiKey != null) 'uniunApiKey': uniunApiKey,
        },
      );
    } catch (e) {
      debugPrint('GanaWorkmanagerBootstrap.scheduleBackground failed: $e');
    }
  }

  /// Cancel any pending bg tick. Call on `AppLifecycleState.resumed` —
  /// the foreground engine takes over.
  static Future<void> cancelBackground() async {
    try {
      await Workmanager().cancelByUniqueName(_tickUniqueName);
    } catch (e) {
      debugPrint('GanaWorkmanagerBootstrap.cancelBackground failed: $e');
    }
  }
}
