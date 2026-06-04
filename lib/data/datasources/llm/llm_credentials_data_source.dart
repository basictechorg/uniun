import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Stores cloud LLM credentials in the device keychain.
///
/// API keys must NEVER live in Isar or SharedPreferences — same hard rule
/// as `nsec`. We mirror the storage pattern used in
/// `UserRepositoryImpl` (Android Keystore / iOS Keychain).
@singleton
class LlmCredentialsDataSource {
  static const _kOpenRouterKey = 'uniun_llm_openrouter_key';

  final FlutterSecureStorage _storage;

  LlmCredentialsDataSource()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<String?> getOpenRouterKey() => _storage.read(key: _kOpenRouterKey);

  Future<void> setOpenRouterKey(String key) =>
      _storage.write(key: _kOpenRouterKey, value: key);

  Future<void> clearOpenRouterKey() => _storage.delete(key: _kOpenRouterKey);

  Future<bool> hasOpenRouterKey() async {
    final v = await _storage.read(key: _kOpenRouterKey);
    return v != null && v.isNotEmpty;
  }
}
