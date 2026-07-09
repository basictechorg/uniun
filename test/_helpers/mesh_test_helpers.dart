import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';

/// Shared mesh-test plumbing: the identity+codec pair and the
/// flutter_secure_storage channel stub that every mesh suite needs.
/// Scope-specific row builders (each scope syncs a different model) stay in
/// their own test file; only what is copy-pasted across files lives here.

/// Stubs the flutter_secure_storage MethodChannel with a no-op handler.
///
/// NIP-44 v2 pulls in flutter_secure_storage inside its PBKDF2 helper on
/// some paths — without this, any test that signs/opens a mesh record can
/// fail platform-side. Call once at the top of `main()`; it also ensures the
/// widgets binding is initialized (the messenger needs it).
void stubSecureStorageChannel() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => null);
}

/// A real Schnorr keypair with a [MeshEventCodec] bound to it.
///
/// `MeshIdentity.generate()` is the test's "me"; generate a second one to
/// play the attacker in signed-by-another-identity drop tests.
class MeshIdentity {
  MeshIdentity._(this.keys, this.codec);

  factory MeshIdentity.generate() {
    final keys = Keychain.generate();
    return MeshIdentity._(
      keys,
      MeshEventCodec(privkeyHex: keys.private, pubkeyHex: keys.public),
    );
  }

  final Keychain keys;
  final MeshEventCodec codec;

  String get pubkey => keys.public;
  String get privkey => keys.private;
}
