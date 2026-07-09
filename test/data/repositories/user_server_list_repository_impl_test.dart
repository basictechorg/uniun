import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/repositories/user_server_list_repository_impl.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/recording_event_queue.dart';
import '../../_helpers/stub_user_repository.dart';

/// Covers: UserServerListRepositoryImpl getServers default fallback,
/// setServers persistence + best-effort Kind-10063 publish (server tags,
/// signed identity, silent skip when logged out).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserServerListStore store;
  late RecordingEventQueue events;
  late StubUserRepository user;
  late UserServerListRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = UserServerListStore(await SharedPreferences.getInstance());
    events = RecordingEventQueue();
    user = StubUserRepository()
      // The publish path decodes user.nsec — needs a real bech32 nsec.
      ..activeUser = aUserKey(
        pubkeyHex: Keychain(kTestPrivHex).public,
        nsec: Nip19.encodePrivkey(kTestPrivHex),
      );
    repo = UserServerListRepositoryImpl(
      store: store,
      eventQueue: events,
      getActiveUserKeys: GetActiveUserKeysUseCase(user),
    );
  });

  group('getServers', () {
    test('empty store → falls back to the default Blossom server', () async {
      final r = await repo.getServers();
      expect(r.getOrElse(() => const []), [AppConstants.kUniunBlossom]);
    });

    test('returns the stored list when set', () async {
      await store.setServers(['https://a', 'https://b']);
      final r = await repo.getServers();
      expect(r.getOrElse(() => const []), ['https://a', 'https://b']);
    });
  });

  group('setServers', () {
    test('persists locally and publishes a Kind-10063 event with server tags',
        () async {
      final r = await repo.setServers(['https://a', 'https://b']);
      expect(r.isRight(), isTrue);
      expect(store.servers, ['https://a', 'https://b']);

      final call = events.calls.single;
      expect(call.kind, 10063);
      expect(call.serverTags, ['https://a', 'https://b']);
      expect(call.content, '');
      expect(call.eTagRefs, isEmpty);
      expect(call.pTagRefs, isEmpty);
      expect(call.authorPubkey, matches(r'^[0-9a-f]{64}$'));
      expect(call.sig, matches(r'^[0-9a-f]{120,128}$'));
    });

    test('logged out → local save succeeds, publish silently skipped',
        () async {
      user
        ..activeUser = null
        ..keys = null;
      final r = await repo.setServers(['https://a']);
      expect(r.isRight(), isTrue);
      expect(store.servers, ['https://a']);
      expect(events.calls, isEmpty);
    });

    test('publish failure is swallowed — local snapshot stays authoritative',
        () async {
      events.throwOnEnqueue = true;
      final r = await repo.setServers(['https://a']);
      expect(r.isRight(), isTrue);
      expect(store.servers, ['https://a']);
    });

    test('empty list persists and publishes an event with no server tags',
        () async {
      await store.setServers(['https://old']);
      final r = await repo.setServers([]);
      expect(r.isRight(), isTrue);
      expect(store.servers, isEmpty);
      expect(events.calls.single.serverTags, isEmpty);
      // getServers now falls back to the default again.
      final read = await repo.getServers();
      expect(read.getOrElse(() => const []), [AppConstants.kUniunBlossom]);
    });
  });
}
