import 'dart:convert';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as bip340;
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:pointycastle/export.dart' show ECDomainParameters;
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/data/repositories/uniun_repository_impl.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';

import '../../_helpers/stub_user_repository.dart';

/// Returns [name] as the local profile's `name` on every lookup — enough
/// for [UniunRepositoryImpl]'s best-effort profile push after a fresh mint.
class _StubProfileRepository implements ProfileRepository {
  _StubProfileRepository({this.name});
  final String? name;

  @override
  Future<Either<Failure, ProfileEntity?>> getOwnProfile(String pubkeyHex) async =>
      Right(name == null
          ? null
          : ProfileEntity(
              pubkey: pubkeyHex, name: name, updatedAt: DateTime.now()));

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String pubkey) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, ProfileEntity>> saveProfile(ProfileEntity profile) =>
      throw UnimplementedError();
  @override
  Stream<ProfileEntity?> watchProfile(String pubkeyHex) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> requestProfileFetch(String pubkeyHex) =>
      throw UnimplementedError();
}

/// Test-side mirror of the server's `encrypted_api_key` encryption — the
/// exact inverse of `UniunKeyRecoveryCipher.decrypt`. Builds a real
/// ephemeral-ECDH + HKDF-SHA256 + ChaCha20-Poly1305 blob so these tests
/// exercise the actual decrypt path, not a stub.
Future<String> _encryptApiKey(String rawApiKey, String privkeyHex) async {
  final domain = ECDomainParameters('secp256k1');
  final d = BigInt.parse(privkeyHex, radix: 16);
  final userPoint = domain.G * d; // our own pubkey point, derived directly

  // Ephemeral key pair for this one message.
  final e = BigInt.parse(sha256.convert(utf8.encode(rawApiKey)).toString(),
          radix: 16) %
      domain.n;
  final ephemeralPoint = domain.G * e;
  final sharedPoint = userPoint! * e;
  final sharedX = _bigIntToBytes(sharedPoint!.x!.toBigInteger()!, 32);

  final symKey = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: SecretKey(sharedX),
    // RFC 5869: an omitted salt is HashLen zero bytes, not literally empty
    // — mirrors UniunKeyRecoveryCipher.decrypt exactly.
    nonce: List<int>.filled(32, 0),
    info: utf8.encode('uniun-api-key-recovery-v1'),
  );

  const nonce = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  final box = await Chacha20.poly1305Aead().encrypt(
    utf8.encode(rawApiKey),
    secretKey: symKey,
    nonce: nonce,
  );

  final blob = Uint8List.fromList([
    ...ephemeralPoint!.getEncoded(true),
    ...nonce,
    ...box.cipherText,
    ...box.mac.bytes,
  ]);
  return base64.encode(blob);
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final bytes = Uint8List(length);
  var v = value;
  final mask = BigInt.from(0xff);
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (v & mask).toInt();
    v = v >> 8;
  }
  return bytes;
}

/// Covers: UniunRepositoryImpl — the single class composing the raw
/// [UniunGatewayClient] with identity logic (silent challenge→sign→login,
/// decrypting `encrypted_api_key`, key persistence in secure storage,
/// expired-challenge retry, the zero-active-keys recovery mint, 401
/// refresh, and disconnect's last-active-key gate).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory secure storage: LlmCredentialsDataSource is concrete over
  // FlutterSecureStorage, so the platform channel is the seam.
  final vault = <String, String>{};
  setUpAll(() {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      switch (call.method) {
        case 'read':
          return vault[key];
        case 'write':
          vault[key!] = args!['value'] as String;
          return null;
        case 'delete':
          vault.remove(key);
          return null;
        default:
          return null;
      }
    });
  });

  setUp(vault.clear);

  final identity = Keychain.generate();

  UniunRepositoryImpl repoWith(MockClient mock,
      {bool loggedIn = true, String? localName}) {
    final gateway =
        UniunGatewayClient(httpClient: mock, baseUrl: 'https://gw.test');
    final users = StubUserRepository()
      ..keys = loggedIn
          ? (privkeyHex: identity.private, pubkeyHex: identity.public)
          : null;
    final getOwnProfile =
        GetOwnProfileUseCase(_StubProfileRepository(name: localName));
    return UniunRepositoryImpl(
        gateway, LlmCredentialsDataSource(), users, getOwnProfile);
  }

  http.Response ok(Object data) =>
      http.Response(jsonEncode({'data': data}), 200);

  /// Gateway double that issues a fixed challenge and, on login, verifies
  /// the signature shape and challenge echo before returning an
  /// `encrypted_api_key` blob that really decrypts to [rawApiKey].
  MockClient happyGateway({required String challenge, required String rawApiKey}) =>
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/challenge')) {
          return ok({'challenge': challenge});
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['pubkey'], identity.public);
        expect(body['challenge'], challenge);
        // A BIP-340 signature is 64 bytes = 128 hex chars.
        expect(body['signature'], matches(r'^[0-9a-f]{128}$'));
        return ok({
          'encrypted_api_key':
              await _encryptApiKey(rawApiKey, identity.private),
          'key_id': 'kid-1',
          'new_account': true,
        });
      });

  test('first connect: challenge → sign → login decrypts and PERSISTS the '
      'key', () async {
    final repo = repoWith(
        happyGateway(challenge: '1720.abc', rawApiKey: 'uk_fresh'));

    expect(await repo.ensureApiKey(), 'uk_fresh');
    expect(vault.values, contains('uk_fresh'));
    // key_id is persisted too — disconnect needs it to revoke server-side.
    expect(vault['uniun_llm_gateway_key_id'], 'kid-1');
    expect(await repo.isConnected(), isTrue);
  });

  test(
      'fresh mint with no gateway profile yet PUSHES the local Nostr name '
      'as the username', () async {
    String? putBody;
    String? putAuth;
    final repo = repoWith(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/challenge')) {
          return ok({'challenge': '1720.push'});
        }
        if (req.method == 'PUT' && req.url.path.endsWith('/profile')) {
          putBody = req.body;
          putAuth = req.headers['Authorization'];
          return ok({'username': 'sam_test'});
        }
        return ok({
          'encrypted_api_key':
              await _encryptApiKey('uk_fresh', identity.private),
          'key_id': 'kid-1',
          'new_account': true,
          'has_profile': false,
        });
      }),
      localName: 'Sam Test',
    );

    await repo.ensureApiKey();

    expect(putAuth, 'Bearer uk_fresh');
    expect(jsonDecode(putBody!), {'username': 'sam_test'});
  });

  test(
      'fresh mint SKIPS the push when the gateway already has a username',
      () async {
    var putCalled = false;
    final repo = repoWith(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/challenge')) {
          return ok({'challenge': '1720.skip'});
        }
        if (req.method == 'PUT' && req.url.path.endsWith('/profile')) {
          putCalled = true;
          return ok({});
        }
        return ok({
          'encrypted_api_key':
              await _encryptApiKey('uk_fresh2', identity.private),
          'key_id': 'kid-2',
          'new_account': true,
          'has_profile': true,
        });
      }),
      localName: 'Sam Test',
    );

    await repo.ensureApiKey();

    expect(putCalled, isFalse);
  });

  test('the signature is a REAL Schnorr over sha256(challenge) — self-check '
      'with the identity pubkey', () async {
    String? sentSig;
    const challenge = '1720999.deadbeef';
    final repo = repoWith(MockClient((req) async {
      if (req.url.path.endsWith('/auth/challenge')) {
        return ok({'challenge': challenge});
      }
      sentSig =
          (jsonDecode(req.body) as Map<String, dynamic>)['signature'] as String;
      return ok({
        'encrypted_api_key': await _encryptApiKey('uk_x', identity.private),
        'new_account': true,
      });
    }));

    await repo.ensureApiKey();
    // Same check the gateway runs: BIP-340 verify of sha256(challenge)
    // under the x-only pubkey.
    final digestHex = sha256.convert(utf8.encode(challenge)).toString();
    expect(bip340.verify(identity.public, digestHex, sentSig!), isTrue);
  });

  test('stored key short-circuits — no network call on later uses', () async {
    vault['uniun_llm_gateway_key'] = 'uk_existing';
    var hits = 0;
    final repo = repoWith(MockClient((req) async {
      hits++;
      return ok({});
    }));

    expect(await repo.ensureApiKey(), 'uk_existing');
    expect(hits, 0);
  });

  test('no app identity → null (nothing to sign with), no network', () async {
    var hits = 0;
    final repo = repoWith(MockClient((req) async {
      hits++;
      return ok({});
    }), loggedIn: false);

    expect(await repo.ensureApiKey(), isNull);
    expect(hits, 0);
  });

  test('expired challenge on first attempt retries once with a fresh one',
      () async {
    var logins = 0;
    final repo = repoWith(MockClient((req) async {
      if (req.url.path.endsWith('/auth/challenge')) {
        return ok({'challenge': 'c-${logins + 1}'});
      }
      logins++;
      if (logins == 1) {
        return http.Response(
            jsonEncode({
              'error': {
                'message': 'challenge invalid or expired',
                'type': 'unauthorized'
              }
            }),
            401);
      }
      return ok({
        'encrypted_api_key': await _encryptApiKey('uk_retry', identity.private),
        'new_account': true,
      });
    }));

    expect(await repo.ensureApiKey(), 'uk_retry');
    expect(logins, 2);
  });

  test(
      'zero active keys (no encrypted_api_key) → recovers via '
      'POST /uniun/v1/keys, raw key persisted directly', () async {
    var challenges = 0;
    final repo = repoWith(MockClient((req) async {
      if (req.url.path.endsWith('/auth/challenge')) {
        challenges++;
        return ok({'challenge': 'c-$challenges'});
      }
      if (req.url.path.endsWith('/auth/login')) {
        return ok({'new_account': false, 'has_profile': true});
      }
      // POST /uniun/v1/keys — the recovery mint.
      expect(req.url.path, '/uniun/v1/keys');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['pubkey'], identity.public);
      return ok({'api_key': 'uk_recovered', 'key_id': 'kid-rec'});
    }));

    expect(await repo.ensureApiKey(), 'uk_recovered');
    expect(vault.values, contains('uk_recovered'));
    expect(vault['uniun_llm_gateway_key_id'], 'kid-rec');
    // One challenge for login, one for the recovery mint.
    expect(challenges, 2);
  });

  test('refreshApiKey forces a fresh login even with a key already stored',
      () async {
    vault['uniun_llm_gateway_key'] = 'uk_stale';
    vault['uniun_llm_gateway_key_id'] = 'kid-stale';
    var logins = 0;
    final repo = repoWith(MockClient((req) async {
      if (req.url.path.endsWith('/auth/challenge')) {
        return ok({'challenge': 'c-refresh'});
      }
      logins++;
      return ok({
        'encrypted_api_key':
            await _encryptApiKey('uk_refreshed', identity.private),
        'key_id': 'kid-fresh',
        'new_account': false,
        'has_profile': true,
      });
    }));

    expect(await repo.refreshApiKey(), 'uk_refreshed');
    expect(logins, 1);
    expect(vault['uniun_llm_gateway_key'], 'uk_refreshed');
    expect(vault['uniun_llm_gateway_key_id'], 'kid-fresh');
  });

  test('connect() wraps ensureApiKey in Either for the Settings UI',
      () async {
    final repo = repoWith(
        happyGateway(challenge: '1720.connect', rawApiKey: 'uk_connect'));

    final result = await repo.connect();
    expect(result, const Right<Failure, Unit>(unit));
    expect(vault.values, contains('uk_connect'));
  });

  test('disconnect REVOKES the key on the gateway, then wipes local state — '
      'otherwise the account keeps an active key and every reconnect '
      'comes back key-less', () async {
    vault['uniun_llm_gateway_key'] = 'uk_gone';
    vault['uniun_llm_gateway_key_id'] = 'kid-9';
    http.Request? revokeReq;
    final repo = repoWith(MockClient((req) async {
      revokeReq = req;
      return ok({'revoked': true});
    }));

    final result = await repo.disconnect();
    expect(result, const Right<Failure, Unit>(unit));
    expect(revokeReq!.method, 'DELETE');
    expect(revokeReq!.url.path, '/uniun/v1/keys/kid-9');
    expect(revokeReq!.headers['Authorization'], 'Bearer uk_gone');
    expect(vault, isEmpty);
    expect(await repo.isConnected(), isFalse);
  });

  test('disconnect on the account\'s last active key 409s as a '
      '"last_active_key" sentinel Failure and does NOT clear local state',
      () async {
    vault['uniun_llm_gateway_key'] = 'uk_last';
    vault['uniun_llm_gateway_key_id'] = 'kid-last';
    final repo = repoWith(MockClient((req) async => http.Response(
        jsonEncode({
          'error': {'message': 'last active key', 'type': 'last_active_key'}
        }),
        409)));

    final result = await repo.disconnect();
    expect(result.fold((f) => f.toMessage(), (_) => null), 'last_active_key');
    expect(vault.values, contains('uk_last'));
  });

  test('disconnect with confirm:true goes through on the last active key',
      () async {
    vault['uniun_llm_gateway_key'] = 'uk_last';
    vault['uniun_llm_gateway_key_id'] = 'kid-last';
    Uri? sentUri;
    final repo = repoWith(MockClient((req) async {
      sentUri = req.url;
      return ok({'revoked': true});
    }));

    final result = await repo.disconnect(confirm: true);
    expect(result, const Right<Failure, Unit>(unit));
    expect(sentUri!.queryParameters, {'confirm': 'true'});
    expect(vault, isEmpty);
  });

  test('offline disconnect still clears local state (revoke is best-effort)',
      () async {
    vault['uniun_llm_gateway_key'] = 'uk_gone';
    vault['uniun_llm_gateway_key_id'] = 'kid-9';
    final repo = repoWith(MockClient((req) async => throw Exception('down')));

    final result = await repo.disconnect();
    expect(result, const Right<Failure, Unit>(unit));
    expect(vault, isEmpty);
  });
}
