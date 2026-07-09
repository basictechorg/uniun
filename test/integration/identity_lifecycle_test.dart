import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/repositories/event_queue_repository_impl.dart';
import 'package:uniun/data/repositories/user_repository_impl.dart';
import 'package:uniun/data/repositories/user_server_list_repository_impl.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../_helpers/isar_test_harness.dart';

/// End-to-end identity lifecycle — onboarding key generation through a real
/// signed publish, logout, and account recovery via nsec import. Wires the
/// real [UserRepositoryImpl] (mock keystore platform), the real
/// [GetActiveUserKeysUseCase], the real [UserServerListRepositoryImpl] as a
/// representative signing publisher, and the real [EventQueueRepositoryImpl]
/// over a real Isar — proving the key that onboarding mints is the key that
/// signs outbound events, before and after an account restore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late UserRepositoryImpl users;
  late UserServerListRepositoryImpl serverList;

  const secureStorage = FlutterSecureStorage();

  setUp(() async {
    isar = await openTestIsar();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    users = UserRepositoryImpl(UserKeyStore(prefs));
    serverList = UserServerListRepositoryImpl(
      store: UserServerListStore(prefs),
      eventQueue: EventQueueRepositoryImpl(isar: isar),
      getActiveUserKeys: GetActiveUserKeysUseCase(users),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<Map<String, dynamic>> lastQueuedEvent() async {
    final rows = await isar.eventQueueModels.where().findAll();
    final wire =
        jsonDecode(rows.last.toSerializedRelayMessage()) as List<dynamic>;
    return wire[1] as Map<String, dynamic>;
  }

  test(
      'SCENARIO: onboarding → generate identity → a publish flow signs with '
      'exactly that identity', () async {
    // 1. Onboarding mints a key.
    final user = (await users.generateKey()).getOrElse(() => throw 'x');

    // 2. The user configures their Blossom server — a real signed Kind-10063
    //    goes to the outbound queue.
    final r = await serverList.setServers(['https://blossom.mine']);
    expect(r.isRight(), isTrue);

    // 3. The queued event is signed BY the generated identity.
    final ev = await lastQueuedEvent();
    expect(ev['pubkey'], user.pubkeyHex);
    expect(ev['kind'], 10063);
    expect(ev['tags'], [
      ['server', 'https://blossom.mine'],
    ]);
    expect(ev['sig'], matches(r'^[0-9a-f]{120,128}$'));
  });

  test(
      'SCENARIO: logout → publishes stop silently → import the SAME nsec → '
      'identity restored, signing resumes under the same pubkey', () async {
    final original = (await users.generateKey()).getOrElse(() => throw 'x');
    await serverList.setServers(['https://a']);
    expect(await isar.eventQueueModels.count(), 1);

    // Logout wipes both halves of the identity.
    await users.logout();
    expect(await users.getActiveKeysHex(), isNull);

    // Publishing while logged out: local save works, nothing enqueued.
    final whileOut = await serverList.setServers(['https://b']);
    expect(whileOut.isRight(), isTrue);
    expect(await isar.eventQueueModels.count(), 1);

    // Account recovery with the nsec the user backed up.
    final restored =
        (await users.importKey(original.nsec)).getOrElse(() => throw 'x');
    expect(restored.pubkeyHex, original.pubkeyHex);
    expect(restored.npub, original.npub);

    // Signing works again — same author pubkey as before logout.
    await serverList.setServers(['https://c']);
    expect(await isar.eventQueueModels.count(), 2);
    expect((await lastQueuedEvent())['pubkey'], original.pubkeyHex);
  });

  test(
      'SCENARIO: Android reinstall — Isar/prefs survive but the keystore is '
      'wiped → app treats the user as logged out and cleans the stale '
      'public identity', () async {
    final user = (await users.generateKey()).getOrElse(() => throw 'x');
    FlutterSecureStorage.setMockInitialValues({}); // keystore wiped

    // Active-user resolution fails closed and clears the orphan public half.
    expect((await users.getActiveUser()).isLeft(), isTrue);
    expect(await users.getActiveKeysHex(), isNull);

    // No publish happens with a half-present identity.
    await serverList.setServers(['https://a']);
    expect(await isar.eventQueueModels.count(), 0);

    // Recovery is still possible with the backed-up nsec.
    final back =
        (await users.importKey(user.nsec)).getOrElse(() => throw 'x');
    expect(back.pubkeyHex, user.pubkeyHex);
  });

  test(
      'SCENARIO: switching accounts — importing a different nsec replaces '
      'the identity completely (no leftovers from the old one)', () async {
    final first = (await users.generateKey()).getOrElse(() => throw 'x');
    final second = (await users.generateKey()).getOrElse(() => throw 'x');
    expect(second.pubkeyHex, isNot(first.pubkeyHex));

    // Active identity is now the second key — storage holds ONE nsec.
    final active = (await users.getActiveUser()).getOrElse(() => throw 'x');
    expect(active.pubkeyHex, second.pubkeyHex);
    expect(await secureStorage.read(key: 'uniun_nsec'), second.nsec);

    // Signing uses the second identity.
    await serverList.setServers(['https://a']);
    expect((await lastQueuedEvent())['pubkey'], second.pubkeyHex);
  });
}
