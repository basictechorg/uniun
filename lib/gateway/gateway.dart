import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/gateway/central_relay_manager.dart';
import 'package:uniun/gateway/gateway_init_message.dart';
import 'package:uniun/data/datasources/isar_schemas.dart';
import 'package:uniun/domain/services/nip17_encryption_service.dart';

/// Entry point for the Gateway isolate (Isolate 2).
///
/// Spawned once at app launch:
/// ```dart
/// await Isolate.spawn(gatewayEntryPoint, GatewayInitMessage(
///   isarDirectory: (await getApplicationDocumentsDirectory()).path,
/// ));
/// ```
///
/// The isolate stays alive for the lifetime of the app because
/// [CentralRelayManager] holds active [Timer]s and stream subscriptions.
/// No [SendPort] is needed — Isar is the shared message bus between isolates.
Future<void> gatewayEntryPoint(GatewayInitMessage init) async {
  try {
    // 2. Attempt to open Isar
    final isar = await Isar.open(
      isarSchemas,
      directory: init.isarDirectory,
      name: Isar.defaultName,
    );

    final manager = CentralRelayManager(isar: isar);
    final nip17Service = Nip17EncryptionService(
      isar,
      privkeyHex: init.privkeyHex,
    );

    await manager.start();
    nip17Service.start();

    debugPrint("Gateway isolate fully started!");
  } catch (e, stackTrace) {
    // 4. Catch and print any silent crashes
    throw Exception("$e\n$stackTrace");
  }
}

/// Bootstrap the Gateway isolate.
class GatewayBootstrap {
  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    final dir = await getApplicationDocumentsDirectory();

    // Read nsec from secure storage (only accessible in the main isolate)
    // and decode to hex before handing off to the background isolate.
    String? privkeyHex;
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final nsec = await storage.read(key: 'uniun_nsec');
      if (nsec != null && nsec.startsWith('nsec1')) {
        privkeyHex = Nip19.decodePrivkey(nsec);
      } else if (nsec != null && nsec.length == 64) {
        privkeyHex = nsec;
      }
    } catch (_) {}

    Isolate.spawn(
      gatewayEntryPoint,
      GatewayInitMessage(isarDirectory: dir.path, privkeyHex: privkeyHex),
    );
  }
}
