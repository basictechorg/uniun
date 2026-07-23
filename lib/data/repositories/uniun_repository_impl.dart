import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/cloud/uniun_key_recovery_cipher.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';

/// Turns the user's Nostr identity into a UNIUN gateway API key, silently,
/// and is the only place that composes [UniunGatewayClient] (raw HTTP) with
/// signing/decryption/secure-storage — everyone else (Settings UI, other
/// datasources needing a Bearer key) goes through this repository instead.
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

  @override
  Future<Either<Failure, Unit>> connect() async {
    try {
      final key = await ensureApiKey();
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
  Future<Either<Failure, ({String plan, num balance})>> accountStatus() async {
    try {
      final key = await ensureApiKey();
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

  @override
  Future<String?> ensureApiKey() async {
    final stored = await _credentials.getUniunApiKey();
    if (stored != null && stored.isNotEmpty) return stored;
    return _loginAndPersist();
  }

  @override
  Future<String?> refreshApiKey() async {
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
