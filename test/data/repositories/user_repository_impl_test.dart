import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/repositories/user_repository_impl.dart';

/// Covers: UserRepositoryImpl generateKey / importKey (nsec, raw hex,
/// malformed) / getActiveUser / getActiveKeysHex / logout, and the
/// secure-storage split invariant: the private key never lands in the
/// SharedPreferences-backed UserKeyStore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late UserRepositoryImpl repo;

  const secureStorage = FlutterSecureStorage();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = UserRepositoryImpl(UserKeyStore(prefs));
  });

  group('generateKey', () {
    test('returns a well-formed identity (npub/nsec prefixes, 64-hex pubkey)',
        () async {
      final r = await repo.generateKey();
      final user = r.getOrElse(() => throw 'unreachable');
      expect(user.pubkeyHex, matches(r'^[0-9a-f]{64}$'));
      expect(user.npub, startsWith('npub1'));
      expect(user.nsec, startsWith('nsec1'));
      // The nsec round-trips to a valid privkey that derives this pubkey.
      final priv = Nip19.decodePrivkey(user.nsec);
      expect(Keychain(priv).public, user.pubkeyHex);
    });

    test('private key goes ONLY to secure storage — never SharedPreferences',
        () async {
      final r = await repo.generateKey();
      final user = r.getOrElse(() => throw 'unreachable');

      expect(await secureStorage.read(key: 'uniun_nsec'), user.nsec);
      // Invariant: no pref value contains the nsec or the raw privkey.
      final priv = Nip19.decodePrivkey(user.nsec);
      for (final key in prefs.getKeys()) {
        final v = prefs.get(key).toString();
        expect(v, isNot(contains(user.nsec)), reason: 'pref $key');
        expect(v, isNot(contains(priv)), reason: 'pref $key');
      }
    });

    test('public identity lands in the UserKeyStore', () async {
      final r = await repo.generateKey();
      final user = r.getOrElse(() => throw 'unreachable');
      final store = UserKeyStore(prefs);
      expect(store.pubkeyHex, user.pubkeyHex);
      expect(store.npub, user.npub);
      expect(store.hasKey, isTrue);
    });

    test('two generations produce distinct identities', () async {
      final a = (await repo.generateKey()).getOrElse(() => throw 'x');
      final b = (await repo.generateKey()).getOrElse(() => throw 'x');
      expect(a.pubkeyHex, isNot(b.pubkeyHex));
    });
  });

  group('importKey', () {
    test('nsec import derives the same identity the key was generated from',
        () async {
      final keychain = Keychain.generate();
      final nsec = Nip19.encodePrivkey(keychain.private);

      final r = await repo.importKey(nsec);
      final user = r.getOrElse(() => throw 'unreachable');
      expect(user.pubkeyHex, keychain.public);
      expect(user.nsec, nsec);
    });

    test('raw 64-char hex privkey import works', () async {
      final keychain = Keychain.generate();
      final r = await repo.importKey(keychain.private);
      expect(r.getOrElse(() => throw 'unreachable').pubkeyHex,
          keychain.public);
    });

    test('unrecognized format → Left, nothing persisted', () async {
      final r = await repo.importKey('hello-world');
      expect(r.isLeft(), isTrue);
      expect(UserKeyStore(prefs).hasKey, isFalse);
      expect(await secureStorage.read(key: 'uniun_nsec'), isNull);
    });

    test('corrupt nsec1 payload → Left', () async {
      final r = await repo.importKey('nsec1qqqqqqqq');
      expect(r.isLeft(), isTrue);
    });

    test('empty string → Left', () async {
      expect((await repo.importKey('')).isLeft(), isTrue);
    });
  });

  group('getActiveUser', () {
    test('no identity at all → Left(notFound)', () async {
      final r = await repo.getActiveUser();
      expect(r.isLeft(), isTrue);
    });

    test('returns the generated identity', () async {
      final created = (await repo.generateKey()).getOrElse(() => throw 'x');
      final r = await repo.getActiveUser();
      final user = r.getOrElse(() => throw 'unreachable');
      expect(user.pubkeyHex, created.pubkeyHex);
      expect(user.npub, created.npub);
      expect(user.nsec, created.nsec);
    });

    test(
        'public identity present but secure storage wiped (reinstall) → '
        'Left AND the stale public identity is cleared', () async {
      await repo.generateKey();
      FlutterSecureStorage.setMockInitialValues({}); // simulate wipe

      final r = await repo.getActiveUser();
      expect(r.isLeft(), isTrue);
      expect(UserKeyStore(prefs).hasKey, isFalse);
    });
  });

  group('getActiveKeysHex', () {
    test('null when logged out', () async {
      expect(await repo.getActiveKeysHex(), isNull);
    });

    test('decodes the stored nsec back to hex', () async {
      final created = (await repo.generateKey()).getOrElse(() => throw 'x');
      final keys = await repo.getActiveKeysHex();
      expect(keys, isNotNull);
      expect(keys!.pubkeyHex, created.pubkeyHex);
      expect(Keychain(keys.privkeyHex).public, created.pubkeyHex);
    });

    test('corrupt secure-storage value → null (no throw)', () async {
      await repo.generateKey();
      await secureStorage.write(key: 'uniun_nsec', value: 'garbage');
      expect(await repo.getActiveKeysHex(), isNull);
    });
  });

  group('logout', () {
    test('clears both secure storage and the public identity', () async {
      await repo.generateKey();
      final r = await repo.logout();
      expect(r.isRight(), isTrue);
      expect(await secureStorage.read(key: 'uniun_nsec'), isNull);
      expect(UserKeyStore(prefs).hasKey, isFalse);
      expect((await repo.getActiveUser()).isLeft(), isTrue);
    });

    test('idempotent when already logged out', () async {
      expect((await repo.logout()).isRight(), isTrue);
    });
  });
}
