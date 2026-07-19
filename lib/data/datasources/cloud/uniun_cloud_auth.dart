import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/domain/repositories/user_repository.dart';

/// Turns the user's Nostr identity into a UNIUN gateway API key, silently.
///
/// There is no signup: the first challenge→sign→login upserts the account on
/// the gateway (plan `free`). The `uk_` key is returned ONLY when minted
/// (first login, or recovery when the account had no active key) — it goes
/// straight into secure storage and every later call reuses it.
///
/// Signing is the exact BIP-340 Schnorr the app already uses for Nostr
/// events, over `sha256(challenge)` — so `Keychain.sign` does all the work.
@lazySingleton
class UniunCloudAuth {
  UniunCloudAuth(this._gateway, this._credentials, this._users);

  final UniunGatewayClient _gateway;
  final LlmCredentialsDataSource _credentials;
  final UserRepository _users;

  /// The stored key, or a fresh one from a silent login. Returns null when
  /// no identity is logged into the app (nothing to sign with).
  ///
  /// Throws [UniunGatewayException] when the gateway rejects the login, and
  /// [UniunKeyUnavailableException] when the account exists with an active
  /// key elsewhere — the server won't re-issue, the user must manage keys
  /// on the website.
  Future<String?> ensureApiKey() async {
    final stored = await _credentials.getUniunApiKey();
    if (stored != null && stored.isNotEmpty) return stored;

    final keys = await _users.getActiveKeysHex();
    if (keys == null) return null;

    final result = await _login(keys.privkeyHex, keys.pubkeyHex);
    final apiKey = result.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      // Account exists and holds an active key we don't have (reinstall /
      // second device). POST /uniun/v1/keys needs a Bearer key, so the app
      // cannot self-recover — surface a clear, actionable state.
      throw const UniunKeyUnavailableException();
    }
    await _credentials.setUniunApiKey(apiKey);
    final keyId = result.keyId;
    if (keyId != null && keyId.isNotEmpty) {
      await _credentials.setUniunKeyId(keyId);
    }
    return apiKey;
  }

  /// True when a key is already in secure storage (no network touched).
  Future<bool> hasStoredKey() => _credentials.hasUniunApiKey();

  /// Revokes this device's key on the gateway, then forgets it locally. The
  /// revoke matters: the server only mints a key for an account with none,
  /// so a disconnect that left the key active would make every reconnect
  /// come back key-less. Best-effort — an offline disconnect still clears
  /// local state (the server key then needs revoking from the website).
  Future<void> disconnect() async {
    final key = await _credentials.getUniunApiKey();
    final keyId = await _credentials.getUniunKeyId();
    if (key != null && key.isNotEmpty && keyId != null && keyId.isNotEmpty) {
      try {
        await _gateway.revokeKey(apiKey: key, keyId: keyId);
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
      final digestHex =
          sha256.convert(utf8.encode(challenge)).toString();
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

/// The account already has an active API key that this device doesn't hold;
/// the gateway only re-issues via an authenticated `POST /uniun/v1/keys`.
class UniunKeyUnavailableException implements Exception {
  const UniunKeyUnavailableException();

  @override
  String toString() =>
      'This identity already has an API key on another device. '
      'Manage your keys at uniun.in.';
}
