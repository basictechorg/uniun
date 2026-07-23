import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

/// Everything the app needs from the UNIUN inference gateway's identity
/// side: turning the user's own Nostr keypair into a gateway API key, and
/// managing that key's lifecycle. The single seam both the Settings UI and
/// any data-layer class that needs a Bearer key for its own gateway calls
/// go through — nobody composes signing/decryption/storage with the raw
/// gateway HTTP client themselves.
///
/// There is no key to paste: [connect] silently logs in with the user's own
/// Nostr keypair (challenge → sign → login) and stores the minted `uk_` key
/// in the device keychain. Keys never leave secure storage.
abstract class UniunRepository {
  /// Ensure the device holds a gateway API key, logging in silently if
  /// needed. First-ever connect auto-creates the account (plan `free`).
  Future<Either<Failure, Unit>> connect();

  /// Forget the stored key. The account and plan live on the gateway;
  /// reconnecting resolves back to the same account via the pubkey.
  ///
  /// When this is the account's only active key, the gateway refuses
  /// unless [confirm] is true — that case comes back as
  /// `Left(Failure.errorFailure('last_active_key'))` (a sentinel, not a
  /// generic error message) so the caller can warn the user and retry with
  /// `confirm: true` instead of just showing it as a failure.
  Future<Either<Failure, Unit>> disconnect({bool confirm = false});

  /// True when a gateway key is already in secure storage.
  Future<bool> isConnected();

  /// Plan name and credit balance of the connected account, straight from
  /// the gateway. Fails when not connected.
  Future<Either<Failure, ({String plan, num balance})>> accountStatus();

  /// The stored key, or a fresh one from a silent login. Returns null when
  /// no identity is logged into the app (nothing to sign with). Any other
  /// data-layer class that needs to attach a Bearer key to its own gateway
  /// call goes through this instead of touching signing/storage itself.
  ///
  /// Throws the gateway's own typed exception when the gateway rejects the
  /// login or the recovery mint.
  Future<String?> ensureApiKey();

  /// Forces a fresh login even if a key is already stored — used to recover
  /// from a 401 on a stored key (revoked elsewhere, or simply stale).
  Future<String?> refreshApiKey();
}
