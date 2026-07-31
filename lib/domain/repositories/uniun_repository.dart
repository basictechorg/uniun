import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/entities/onboarding/onboarding_interest_entity.dart';

/// The ONLY thing anyone imports to talk to the UNIUN inference gateway.
/// Wraps the raw gateway HTTP client (`UniunGatewayClient`, data-layer only,
/// never imported anywhere else) together with all identity/signing/key
/// logic that used to be a separate `UniunCloudAuth` class. No caller ever
/// sees a `uk_` key, a `UniunGatewayException`, or the raw model catalog —
/// everything (auth, catalog filtering, chat streaming, 401 recovery) is
/// resolved inside the implementation.
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

  /// Approves a browser's QR-login session (`docs/frontend/QR-LOGIN.md` on
  /// the gateway) by signing [sessionId] with this device's own Nostr key
  /// and handing the browser this account's `uk_` key. Callers MUST check
  /// [isConnected] first and route to Settings when false — this method
  /// does not silently connect, since approving on behalf of an account the
  /// user hasn't consciously signed into on this device would be wrong.
  Future<Either<Failure, Unit>> approveQrLogin(String sessionId);

  /// Plan name and credit balance of the connected account, straight from
  /// the gateway. Fails when not connected.
  Future<Either<Failure, ({String plan, num balance})>> accountStatus();

  /// The cloud model catalog, already filtered to what this account can
  /// actually use: free models always, paid models when the plan covers
  /// them or the account holds a credit balance. Signs in silently if
  /// needed; a stale key is refreshed and retried once, transparently.
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels();

  /// Streams completion tokens for [modelId] given an OpenAI-shaped
  /// `messages` list. Resolves a valid key internally (signing in silently
  /// if needed) and retries once on a stale key. Throws
  /// [UniunNotConnectedException] when no identity is logged into the app.
  Stream<String> streamChat({
    required String modelId,
    required List<Map<String, String>> messages,
    int? maxTokens,
  });

  /// The onboarding interest-picker roster — public, no auth, no local
  /// identity required. Backend-owned so new house accounts can be added
  /// without an app release; see `docs/frontend/ONBOARDING-INTERESTS.md` on
  /// the gateway.
  Future<Either<Failure, List<OnboardingInterestEntity>>>
      getOnboardingInterests();
}

/// Thrown by [UniunRepository.streamChat] when there is no Nostr identity
/// to sign in with — nothing to attempt, silent or otherwise.
class UniunNotConnectedException implements Exception {
  const UniunNotConnectedException();
  @override
  String toString() => 'Sign in to UNIUN before using cloud AI';
}
