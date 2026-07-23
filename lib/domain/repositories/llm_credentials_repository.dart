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
}
