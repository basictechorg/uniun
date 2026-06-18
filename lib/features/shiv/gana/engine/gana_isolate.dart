import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/datasources/isar_schemas.dart';
import 'package:uniun/features/shiv/gana/engine/gana_engine.dart';
import 'package:uniun/features/shiv/gana/engine/gana_init_message.dart';

/// Entry point for the Gana isolate.
///
/// Owns its own Isar handle at the same DB path as the main isolate + the
/// gateway. Isar is the inter-isolate bus — the Gana engine never receives
/// messages from the main isolate other than the initial [GanaInitMessage]
/// + the inference-bridge replies on per-request ports.
Future<void> ganaEntryPoint(GanaInitMessage init) async {
  try {
    final isar = await Isar.open(
      isarSchemas,
      directory: init.isarDirectory,
      name: Isar.defaultName,
    );

    if (init.selfPubkeyHex == null) {
      // No user logged in yet — the engine has nothing meaningful to do.
      // Stay alive so the next launch (which will spawn fresh) doesn't have
      // a phantom isolate competing.
      debugPrint('Gana isolate: no active user, idling');
      return;
    }

    final engine = GanaEngine(
      isar: isar,
      selfPubkeyHex: init.selfPubkeyHex!,
      inferencePort: init.mainInferencePort,
    );

    await engine.start();
    debugPrint('Gana engine isolate fully started');
  } catch (e, st) {
    throw Exception('Gana engine isolate failed: $e\n$st');
  }
}
