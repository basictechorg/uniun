import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/profile_model.dart';

/// Cross-cutting inbound middleware.
///
/// For every inbound event with a pubkey we don't have a [ProfileModel] for,
/// records a [MissingProfilePubkeyModel] so the profile subscription can fetch
/// the kind 0 metadata later. Idempotent — protected by the unique index.
class MissingProfileTracker {
  final Isar _isar;
  MissingProfileTracker(this._isar);

  Future<void> track(Map<String, dynamic> event) async {
    final pubkey = event['pubkey'] as String?;
    await trackPubkey(pubkey);
  }

  /// Direct-pubkey entry point — used by decrypt paths (private channel MLS,
  /// NIP-17 DM seals) where there is no raw inbound event to inspect, only
  /// the sender pubkey extracted from the decrypted payload.
  Future<void> trackPubkey(String? pubkey) async {
    if (pubkey == null || pubkey.isEmpty) return;

    final existingProfile = await _isar.profileModels
        .where()
        .pubkeyEqualTo(pubkey)
        .findFirst();
    if (existingProfile != null) return;

    try {
      await _isar.writeTxn(() async {
        final existingMissing = await _isar.missingProfilePubkeyModels
            .where()
            .pubkeyEqualTo(pubkey)
            .findFirst();
        if (existingMissing != null) return;
        final row = MissingProfilePubkeyModel()
          ..pubkey = pubkey
          ..firstSeenAt = DateTime.now();
        await _isar.missingProfilePubkeyModels.put(row);
      });
    } catch (_) {
      // unique-index race — fine
    }
  }
}
