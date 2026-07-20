import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

/// Manages the UNIUN cloud connection for the Settings UI.
///
/// There is no key to paste: [connect] silently logs into the inference
/// gateway with the user's own Nostr keypair (challenge → sign → login) and
/// stores the minted `uk_` key in the device keychain. Keys never leave
/// secure storage.
abstract class LlmCredentialsRepository {
  /// Ensure the device holds a gateway API key, logging in silently if
  /// needed. First-ever connect auto-creates the account (plan `free`).
  Future<Either<Failure, Unit>> connect();

  /// Forget the stored key. The account and plan live on the gateway;
  /// reconnecting resolves back to the same account via the pubkey.
  Future<Either<Failure, Unit>> disconnect();

  /// True when a gateway key is already in secure storage.
  Future<bool> isConnected();

  /// Plan name and credit balance of the connected account, straight from
  /// the gateway. Fails when not connected.
  Future<Either<Failure, ({String plan, num balance})>> accountStatus();

  /// Mints a short-lived (~5 min) key for the website checkout handoff —
  /// the permanent key never leaves the device. Fails when not connected.
  Future<Either<Failure, ({String token, int expiresIn})>> mintWebSessionToken();
}
