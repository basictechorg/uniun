import 'dart:convert';

import 'package:bip340/bip340.dart' as bip340;
import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/cloud/uniun_cloud_auth.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';

import '../../../_helpers/stub_user_repository.dart';

/// Returns [name] as the local profile's `name` on every lookup — enough
/// for [UniunCloudAuth]'s best-effort profile push after a fresh mint.
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

/// Covers: UniunCloudAuth — silent challenge→sign→login, key persistence in
/// secure storage, expired-challenge retry, and the no-key recovery states.
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

  UniunCloudAuth authWith(MockClient mock,
      {bool loggedIn = true, String? localName}) {
    final gateway =
        UniunGatewayClient(httpClient: mock, baseUrl: 'https://gw.test');
    final users = StubUserRepository()
      ..keys = loggedIn
          ? (privkeyHex: identity.private, pubkeyHex: identity.public)
          : null;
    final getOwnProfile =
        GetOwnProfileUseCase(_StubProfileRepository(name: localName));
    return UniunCloudAuth(
        gateway, LlmCredentialsDataSource(), users, getOwnProfile);
  }

  http.Response ok(Object data) =>
      http.Response(jsonEncode({'data': data}), 200);

  /// Gateway double that issues a fixed challenge and, on login, verifies
  /// the signature shape and challenge echo before minting a key.
  MockClient happyGateway({required String challenge, String? apiKey}) =>
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
          if (apiKey != null) 'api_key': apiKey,
          if (apiKey != null) 'key_id': 'kid-1',
          'new_account': apiKey != null,
        });
      });

  test('first connect: challenge → sign → login mints and PERSISTS the key',
      () async {
    final auth = authWith(
        happyGateway(challenge: '1720.abc', apiKey: 'uk_fresh'));

    expect(await auth.ensureApiKey(), 'uk_fresh');
    expect(vault.values, contains('uk_fresh'));
    // key_id is persisted too — disconnect needs it to revoke server-side.
    expect(vault['uniun_llm_gateway_key_id'], 'kid-1');
    expect(await auth.hasStoredKey(), isTrue);
  });

  test(
      'fresh mint with no gateway profile yet PUSHES the local Nostr name '
      'as the username', () async {
    String? putBody;
    String? putAuth;
    final auth = authWith(
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
          'api_key': 'uk_fresh',
          'key_id': 'kid-1',
          'new_account': true,
          'has_profile': false,
        });
      }),
      localName: 'Sam Test',
    );

    await auth.ensureApiKey();

    expect(putAuth, 'Bearer uk_fresh');
    expect(jsonDecode(putBody!), {'username': 'sam_test'});
  });

  test(
      'fresh mint SKIPS the push when the gateway already has a username',
      () async {
    var putCalled = false;
    final auth = authWith(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/challenge')) {
          return ok({'challenge': '1720.skip'});
        }
        if (req.method == 'PUT' && req.url.path.endsWith('/profile')) {
          putCalled = true;
          return ok({});
        }
        return ok({
          'api_key': 'uk_fresh2',
          'key_id': 'kid-2',
          'new_account': true,
          'has_profile': true,
        });
      }),
      localName: 'Sam Test',
    );

    await auth.ensureApiKey();

    expect(putCalled, isFalse);
  });

  test('the signature is a REAL Schnorr over sha256(challenge) — self-check '
      'with the identity pubkey', () async {
    String? sentSig;
    const challenge = '1720999.deadbeef';
    final auth = authWith(MockClient((req) async {
      if (req.url.path.endsWith('/auth/challenge')) {
        return ok({'challenge': challenge});
      }
      sentSig =
          (jsonDecode(req.body) as Map<String, dynamic>)['signature'] as String;
      return ok({'api_key': 'uk_x', 'new_account': true});
    }));

    await auth.ensureApiKey();
    // Same check the gateway runs: BIP-340 verify of sha256(challenge)
    // under the x-only pubkey.
    final digestHex = sha256.convert(utf8.encode(challenge)).toString();
    expect(bip340.verify(identity.public, digestHex, sentSig!), isTrue);
  });

  test('stored key short-circuits — no network call on later uses', () async {
    vault['uniun_llm_gateway_key'] = 'uk_existing';
    var hits = 0;
    final auth = authWith(MockClient((req) async {
      hits++;
      return ok({});
    }));

    expect(await auth.ensureApiKey(), 'uk_existing');
    expect(hits, 0);
  });

  test('no app identity → null (nothing to sign with), no network', () async {
    var hits = 0;
    final auth = authWith(MockClient((req) async {
      hits++;
      return ok({});
    }), loggedIn: false);

    expect(await auth.ensureApiKey(), isNull);
    expect(hits, 0);
  });

  test('expired challenge on first attempt retries once with a fresh one',
      () async {
    var logins = 0;
    final auth = authWith(MockClient((req) async {
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
      return ok({'api_key': 'uk_retry', 'new_account': true});
    }));

    expect(await auth.ensureApiKey(), 'uk_retry');
    expect(logins, 2);
  });

  test('returning account whose key lives elsewhere → '
      'UniunKeyUnavailableException, nothing persisted', () async {
    final auth =
        authWith(happyGateway(challenge: '1720.abc', apiKey: null));

    expect(() => auth.ensureApiKey(),
        throwsA(isA<UniunKeyUnavailableException>()));
    expect(vault, isEmpty);
  });

  test('disconnect REVOKES the key on the gateway, then wipes local state — '
      'otherwise the account keeps an active key and every reconnect '
      'comes back key-less', () async {
    vault['uniun_llm_gateway_key'] = 'uk_gone';
    vault['uniun_llm_gateway_key_id'] = 'kid-9';
    http.Request? revokeReq;
    final auth = authWith(MockClient((req) async {
      revokeReq = req;
      return ok({'revoked': true});
    }));

    await auth.disconnect();
    expect(revokeReq!.method, 'DELETE');
    expect(revokeReq!.url.path, '/uniun/v1/keys/kid-9');
    expect(revokeReq!.headers['Authorization'], 'Bearer uk_gone');
    expect(vault, isEmpty);
    expect(await auth.hasStoredKey(), isFalse);
  });

  test('offline disconnect still clears local state (revoke is best-effort)',
      () async {
    vault['uniun_llm_gateway_key'] = 'uk_gone';
    vault['uniun_llm_gateway_key_id'] = 'kid-9';
    final auth = authWith(MockClient((req) async => throw Exception('down')));

    await auth.disconnect();
    expect(vault, isEmpty);
  });
}
