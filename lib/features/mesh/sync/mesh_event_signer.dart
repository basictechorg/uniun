import 'package:injectable/injectable.dart';

import 'package:uniun/domain/repositories/user_repository.dart';

import 'mesh_event_codec.dart';

/// Thin façade that turns the active identity into a bound [MeshEventCodec].
///
/// Every mesh-carried mutating write (save/unsave, follow/unfollow, block/…)
/// goes through this so callers don't have to hand-shuffle keys. Returns
/// `null` when no identity is currently logged in — the caller then skips
/// the mesh side-effect (write still lands in Isar; the Phase-0a migration
/// pass will retroactively synthesize a signed event once an identity is
/// present).
///
/// Kept identity-agnostic: keys are fetched per call, so an account switch
/// mid-session doesn't leave a stale codec cached anywhere.
@lazySingleton
class MeshEventSigner {
  MeshEventSigner(this._users);

  final UserRepository _users;

  /// Builds a codec bound to the currently-logged-in identity, or `null`
  /// if there is none. Cheap to call — no secure-storage cache is kept.
  Future<MeshEventCodec?> currentCodec() async {
    final keys = await _users.getActiveKeysHex();
    if (keys == null) return null;
    return MeshEventCodec(
      privkeyHex: keys.privkeyHex,
      pubkeyHex: keys.pubkeyHex,
    );
  }

  /// Signs a mesh record with the currently-logged-in identity.
  ///
  /// Returns `null` if no identity is active — callers must handle this by
  /// leaving the row's `signedNostrEvent` column null (the migration pass
  /// will backfill it later).
  Future<String?> sign({
    required int kind,
    required String dTag,
    required Map<String, dynamic> content,
    int? createdAtSec,
  }) async {
    final codec = await currentCodec();
    if (codec == null) return null;
    return codec.signRecord(
      kind: kind,
      dTag: dTag,
      content: content,
      createdAtSec: createdAtSec,
    );
  }
}
