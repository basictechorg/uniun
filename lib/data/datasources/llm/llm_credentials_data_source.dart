import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Stores the UNIUN gateway API key (`uk_…`) in the device keychain.
///
/// API keys must NEVER live in Isar or SharedPreferences — same hard rule
/// as `nsec`. We mirror the storage pattern used in
/// `UserRepositoryImpl` (Android Keystore / iOS Keychain).
@singleton
class LlmCredentialsDataSource {
  static const _kUniunApiKey = 'uniun_llm_gateway_key';
  static const _kUniunKeyId = 'uniun_llm_gateway_key_id';

  final FlutterSecureStorage _storage;

  LlmCredentialsDataSource()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<String?> getUniunApiKey() => _storage.read(key: _kUniunApiKey);

  Future<void> setUniunApiKey(String key) =>
      _storage.write(key: _kUniunApiKey, value: key);

  Future<void> clearUniunApiKey() => _storage.delete(key: _kUniunApiKey);

  Future<bool> hasUniunApiKey() async {
    final v = await _storage.read(key: _kUniunApiKey);
    return v != null && v.isNotEmpty;
  }

  /// The gateway-side id of the stored key — needed to revoke it on
  /// disconnect so the account can mint a fresh key on the next login.
  Future<String?> getUniunKeyId() => _storage.read(key: _kUniunKeyId);

  Future<void> setUniunKeyId(String id) =>
      _storage.write(key: _kUniunKeyId, value: id);

  Future<void> clearUniunKeyId() => _storage.delete(key: _kUniunKeyId);
}
