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

  /// Kinds whose `pubkey` is never a profile-bearing user identity, so they
  /// must not seed the missing-profile table:
  ///   - 0    — the profile event itself. Tracking it races the
  ///            [Kind0ProfileHandler] upsert/delete in the same inbound pass
  ///            and would re-create the row we just cleared (perpetual refetch).
  ///   - 1059 — NIP-17 gift wrap. `pubkey` is an ephemeral wrapper key with no
  ///            kind-0 metadata; it would never resolve and would grow the
  ///            table — and thus the profiles REQ `authors` list — unbounded.
  ///            The real DM sender is tracked via [trackPubkey] from the
  ///            decrypt path instead.
  static const Set<int> _untrackedKinds = {0, 1059};

  Future<void> track(Map<String, dynamic> event) async {
    final kind = event['kind'] as int?;
    // Skip the untracked kinds; also skip events we can't classify (no/invalid
    // kind) rather than seeding a pubkey from a malformed event into the
    // profiles `authors` list.
    if (kind == null || _untrackedKinds.contains(kind)) return;
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
