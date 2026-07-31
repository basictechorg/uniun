import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/cloud/uniun_key_recovery_cipher.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/entities/onboarding/onboarding_interest_entity.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';

/// The only class in the app that imports [UniunGatewayClient]. Every other
/// consumer (datasources, other repos) goes through [UniunRepository] —
/// nobody else sees a `uk_` key, a [UniunGatewayException], or the raw
/// model catalog. This one class composes the raw HTTP client with
/// signing/decryption/secure-storage AND the catalog/credit filtering and
/// chat streaming that used to live in `RemoteLlmDataSource`.
///
/// There is no signup: the first challenge→sign→login upserts the account on
/// the gateway (plan `free`). The `uk_` key is decrypted from
/// `encrypted_api_key` (or minted fresh via recovery when the account has
/// zero active keys) and goes straight into secure storage.
///
/// Signing is the exact BIP-340 Schnorr the app already uses for Nostr
/// events, over `sha256(challenge)` — so `Keychain.sign` does all the work.
@Injectable(as: UniunRepository)
class UniunRepositoryImpl implements UniunRepository {
  UniunRepositoryImpl(
      this._gateway, this._credentials, this._users, this._getOwnProfile);

  final UniunGatewayClient _gateway;
  final LlmCredentialsDataSource _credentials;
  final UserRepository _users;
  final GetOwnProfileUseCase _getOwnProfile;

  // ── Connection lifecycle (Settings UI) ──────────────────────────────────

  @override
  Future<Either<Failure, Unit>> connect() async {
    try {
      final key = await _ensureApiKey();
      if (key == null) {
        return const Left(
            Failure.errorFailure('No active identity to sign in with'));
      }
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> disconnect({bool confirm = false}) async {
    try {
      await _disconnect(confirm: confirm);
      return const Right(unit);
    } on UniunGatewayException catch (e) {
      if (e.statusCode == 409) {
        return const Left(Failure.errorFailure('last_active_key'));
      }
      return Left(Failure.errorFailure(e.toString()));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<bool> isConnected() => _credentials.hasUniunApiKey();

  @override
  Future<Either<Failure, Unit>> approveQrLogin(String sessionId) async {
    try {
      final keys = await _users.getActiveKeysHex();
      final apiKey = await _credentials.getUniunApiKey();
      if (keys == null || apiKey == null || apiKey.isEmpty) {
        return const Left(Failure.errorFailure('Not connected'));
      }
      final digestHex = sha256.convert(utf8.encode(sessionId)).toString();
      final signature = Keychain(keys.privkeyHex).sign(digestHex);
      await _gateway.approveQrSession(
        sessionId: sessionId,
        pubkeyHex: keys.pubkeyHex,
        signatureHex: signature,
        rawKey: apiKey,
      );
      return const Right(unit);
    } on UniunGatewayException catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ({String plan, num balance})>> accountStatus() async {
    try {
      final key = await _ensureApiKey();
      if (key == null) {
        return const Left(Failure.errorFailure('Not connected'));
      }
      final credits = await _gateway.getCredits(key);
      return Right((
        plan: (credits['plan'] as String?) ?? 'free',
        balance: (credits['balance'] as num?) ?? 0,
      ));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Catalog + chat ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<LlmModelInfo>>> listAvailableModels() async {
    try {
      var apiKey = await _ensureApiKey();
      if (apiKey == null) return const Right([]);

      // `getCredits` already carries `plan` alongside `balance` — one call,
      // not a separate `getProfile` just for the plan name.
      Map<String, dynamic> credits;
      try {
        credits = await _gateway.getCredits(apiKey);
      } on UniunGatewayException catch (e) {
        // A stored key can go stale (revoked elsewhere, or just expired) —
        // silently redo the login once and retry before surfacing the error.
        if (e.type != UniunGatewayErrorType.unauthorized) rethrow;
        final refreshed = await _refreshApiKey();
        if (refreshed == null) rethrow;
        apiKey = refreshed;
        credits = await _gateway.getCredits(apiKey);
      }

      // Catalog is public; the account's plan decides what serves flat-rate.
      // `category == "free"` rows are open to everyone on the gateway, no
      // charge and no plan check — they're cloud-servable too, not just the
      // on-device tier (the app's own local catalog is a separate list).
      final catalog = await _gateway.listModels();
      final plan = credits['plan'] as String?;
      final plans = await _gateway.listPlans();
      final allowed = <String>{
        for (final p in plans)
          if (p['name'] == plan)
            ...((p['models'] as List<dynamic>? ?? const []).cast<String>()),
      };

      // Gateway rule: free models are always usable. A paid model serves
      // when the plan covers it, OR when the account holds a credit balance
      // (billed per-token). Zero balance and no covering plan → the server
      // answers 403 model_not_allowed.
      final balance = (credits['balance'] as num?) ?? 0;

      final infos = [
        for (final m in catalog)
          if (!m.isPaid || allowed.contains(m.id) || balance > 0)
            LlmModelInfo(
              id: m.id,
              displayName: m.displayName,
              backend: LlmBackendType.uniunCloud,
            ),
      ]..sort((a, b) => a.displayName.compareTo(b.displayName));
      return Right(infos);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Stream<String> streamChat({
    required String modelId,
    required List<Map<String, String>> messages,
    int? maxTokens,
  }) async* {
    final apiKey = await _ensureApiKey();
    if (apiKey == null) {
      throw const UniunNotConnectedException();
    }
    try {
      // `await for` + `yield`, NOT `yield* stream`: an exception thrown by a
      // delegated async* stream does not reach a `try` wrapping `yield*` —
      // only a `try` wrapping an `await for` loop actually catches it.
      await for (final token in _gateway.streamChatCompletion(
        apiKey: apiKey,
        modelId: modelId,
        messages: messages,
        maxTokens: maxTokens,
      )) {
        yield token;
      }
    } on UniunGatewayException catch (e) {
      // A stored key can go stale (revoked elsewhere, or just expired) —
      // silently redo the login once and retry before surfacing the error.
      if (e.type != UniunGatewayErrorType.unauthorized) rethrow;
      final refreshed = await _refreshApiKey();
      if (refreshed == null) rethrow;
      await for (final token in _gateway.streamChatCompletion(
        apiKey: refreshed,
        modelId: modelId,
        messages: messages,
        maxTokens: maxTokens,
      )) {
        yield token;
      }
    }
  }

  @override
  Future<Either<Failure, List<OnboardingInterestEntity>>>
      getOnboardingInterests() async {
    try {
      final rows = await _gateway.listOnboardingInterests();
      return Right([
        for (final r in rows)
          OnboardingInterestEntity(
            id: r['id'] as int,
            name: r['name'] as String,
            pubkeyHex: r['pubkey_hex'] as String,
          ),
      ]);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  // ── Identity / key lifecycle (private — nobody outside this class ever
  //    sees a raw key) ──────────────────────────────────────────────────────

  /// The stored key, or a fresh one from a silent login. Returns null when
  /// no identity is logged into the app (nothing to sign with).
  Future<String?> _ensureApiKey() async {
    final stored = await _credentials.getUniunApiKey();
    if (stored != null && stored.isNotEmpty) return stored;
    return _loginAndPersist();
  }

  /// Forces a fresh login even if a key is already stored — used to recover
  /// from a 401 on a stored key (revoked elsewhere, or simply stale).
  Future<String?> _refreshApiKey() async {
    final keys = await _users.getActiveKeysHex();
    if (keys == null) return null;
    await _credentials.clearUniunApiKey();
    await _credentials.clearUniunKeyId();
    return _loginAndPersist();
  }

  Future<String?> _loginAndPersist() async {
    final keys = await _users.getActiveKeysHex();
    if (keys == null) return null;

    final result = await _login(keys.privkeyHex, keys.pubkeyHex);
    final resolved = await _resolveApiKey(result, keys.privkeyHex, keys.pubkeyHex);

    await _credentials.setUniunApiKey(resolved.apiKey);
    final keyId = resolved.keyId;
    if (keyId != null && keyId.isNotEmpty) {
      await _credentials.setUniunKeyId(keyId);
    }
    // Gateway has no username yet — push the app's own Nostr profile name
    // up once, so the account isn't blank on the website either. Best
    // effort: a taken/invalid username just leaves the gateway profile
    // empty, no different from not calling this at all.
    if (!result.hasProfile) {
      await _pushLocalProfile(resolved.apiKey, keys.pubkeyHex);
    }
    return resolved.apiKey;
  }

  /// Decrypts [UniunLoginResult.encryptedApiKey] when present. When the
  /// account has zero active keys (encryptedApiKey null), mints a fresh one
  /// via a second challenge/sign round against `/uniun/v1/keys`.
  Future<({String apiKey, String? keyId})> _resolveApiKey(
    UniunLoginResult result,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    final encrypted = result.encryptedApiKey;
    if (encrypted != null && encrypted.isNotEmpty) {
      final apiKey = await UniunKeyRecoveryCipher.decrypt(encrypted, privkeyHex);
      return (apiKey: apiKey, keyId: result.keyId);
    }
    final challenge = await _gateway.fetchChallenge(pubkeyHex);
    final digestHex = sha256.convert(utf8.encode(challenge)).toString();
    final signature = Keychain(privkeyHex).sign(digestHex);
    final recovered = await _gateway.recoverKey(
      pubkeyHex: pubkeyHex,
      challenge: challenge,
      signatureHex: signature,
    );
    return (apiKey: recovered.apiKey, keyId: recovered.keyId);
  }

  Future<void> _pushLocalProfile(String apiKey, String pubkeyHex) async {
    try {
      final profile = await _getOwnProfile.call(pubkeyHex);
      final name = profile.fold((_) => null, (p) => p?.name);
      final username = _sanitizeUsername(name);
      if (username == null) return;
      await _gateway.updateProfile(apiKey: apiKey, username: username);
    } catch (_) {
      // Network error, taken username, bad format — the gateway profile
      // just stays empty, same as if we'd never tried.
    }
  }

  /// Gateway usernames are `[a-z0-9_]{3,32}`, lowercased. A Nostr display
  /// name can be anything, so this is a best-effort mapping, not a full
  /// validator — the gateway itself is the source of truth on acceptance.
  static String? _sanitizeUsername(String? name) {
    if (name == null || name.isEmpty) return null;
    final cleaned =
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final trimmed = cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
    return trimmed.length >= 3 ? trimmed : null;
  }

  /// Revokes this device's key on the gateway, then forgets it locally. The
  /// revoke matters: the server only mints a key for an account with none,
  /// so a disconnect that left the key active would make every reconnect
  /// come back key-less. Best-effort — an offline disconnect still clears
  /// local state (the server key then needs revoking from the website).
  ///
  /// The server 409s when this is the account's only active key; that
  /// rethrows [UniunGatewayException] (statusCode 409) with local state
  /// left untouched, so the caller can warn the user and retry with
  /// [confirm]: true.
  Future<void> _disconnect({bool confirm = false}) async {
    final key = await _credentials.getUniunApiKey();
    final keyId = await _credentials.getUniunKeyId();
    if (key != null && key.isNotEmpty && keyId != null && keyId.isNotEmpty) {
      try {
        await _gateway.revokeKey(apiKey: key, keyId: keyId, confirm: confirm);
      } on UniunGatewayException catch (e) {
        if (e.statusCode == 409 && !confirm) rethrow;
        // Offline, already revoked, or confirmed anyway — local cleanup
        // still proceeds.
      } catch (_) {
        // Offline or already revoked — local cleanup still proceeds.
      }
    }
    await _credentials.clearUniunApiKey();
    await _credentials.clearUniunKeyId();
  }

  Future<UniunLoginResult> _login(String privkeyHex, String pubkeyHex) async {
    // Challenges expire in ~60 s; fetch-sign-redeem in one shot and retry
    // once on an expiry race (slow network / background suspension).
    for (var attempt = 0; ; attempt++) {
      final challenge = await _gateway.fetchChallenge(pubkeyHex);
      final digestHex = sha256.convert(utf8.encode(challenge)).toString();
      final signature = Keychain(privkeyHex).sign(digestHex);
      try {
        return await _gateway.login(
          pubkeyHex: pubkeyHex,
          challenge: challenge,
          signatureHex: signature,
        );
      } on UniunGatewayException catch (e) {
        final expired = e.type == UniunGatewayErrorType.unauthorized ||
            e.message.contains('challenge');
        if (attempt == 0 && expired) continue;
        rethrow;
      }
    }
  }
}
