import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/data/repositories/relay_repository_impl.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: RelayRepositoryImpl getAll / save upsert (read-write toggles only,
/// status untouched) / delete with the system-relay guard /
/// insertDefaultRelayIfEmpty seeding + isSystem promotion.
void main() {
  late Isar isar;
  late RelayRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = RelayRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('getAll', () {
    test('empty database → Right(empty)', () async {
      final r = await repo.getAll();
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'unreachable'), isEmpty);
    });

    test('maps every stored relay to its entity', () async {
      await seedRelay(isar, 'wss://a',
          status: RelayStatus.connected, lastConnectedAt: tNow);
      await seedRelay(isar, 'wss://b', read: false, isSystem: true);

      final r = await repo.getAll();
      final list = r.getOrElse(() => throw 'unreachable');
      expect(list, hasLength(2));
      final a = list.firstWhere((e) => e.url == 'wss://a');
      expect(a.status, RelayStatus.connected);
      expect(a.lastConnectedAt!.isAtSameMomentAs(tNow), isTrue);
      final b = list.firstWhere((e) => e.url == 'wss://b');
      expect(b.read, isFalse);
      expect(b.isSystem, isTrue);
    });
  });

  group('save', () {
    test('inserts a new relay as disconnected', () async {
      final r = await repo.save(aRelay(url: 'wss://new'));
      final saved = r.getOrElse(() => throw 'unreachable');
      expect(saved.url, 'wss://new');
      expect(saved.status, RelayStatus.disconnected);
      expect(await isar.relayModels.count(), 1);
    });

    test('upsert updates ONLY read/write — status and isSystem survive',
        () async {
      await seedRelay(isar, 'wss://a',
          status: RelayStatus.connected, isSystem: true);

      final r = await repo.save(aRelay(
        url: 'wss://a',
        read: false,
        write: false,
        // Caller-supplied status/isSystem must be ignored on update.
        status: RelayStatus.reconnecting,
        isSystem: false,
      ));
      final saved = r.getOrElse(() => throw 'unreachable');
      expect(saved.read, isFalse);
      expect(saved.write, isFalse);
      expect(saved.status, RelayStatus.connected);
      expect(saved.isSystem, isTrue);
      expect(await isar.relayModels.count(), 1);
    });

    test('new relay honors the caller isSystem flag', () async {
      await repo.save(aRelay(url: 'wss://sys', isSystem: true));
      final row = (await isar.relayModels.where().findAll()).single;
      expect(row.isSystem, isTrue);
    });
  });

  group('delete', () {
    test('removes a user relay', () async {
      await seedRelay(isar, 'wss://a');
      final r = await repo.delete('wss://a');
      expect(r.isRight(), isTrue);
      expect(await isar.relayModels.count(), 0);
    });

    test('system relay cannot be deleted → Left, row survives', () async {
      await seedRelay(isar, 'wss://sys', isSystem: true);
      final r = await repo.delete('wss://sys');
      expect(r.isLeft(), isTrue);
      expect(await isar.relayModels.count(), 1);
    });

    test('idempotent on unknown url', () async {
      expect((await repo.delete('wss://ghost')).isRight(), isTrue);
    });
  });

  group('insertDefaultRelayIfEmpty', () {
    test('seeds the system relay into an empty database', () async {
      await repo.insertDefaultRelayIfEmpty();
      final row = (await isar.relayModels.where().findAll()).single;
      expect(row.url, AppConstants.kUniunBackend);
      expect(row.isSystem, isTrue);
      expect(row.read, isTrue);
      expect(row.write, isTrue);
      expect(row.status, RelayStatus.disconnected);
    });

    test('idempotent: repeat calls keep a single system row', () async {
      await repo.insertDefaultRelayIfEmpty();
      await repo.insertDefaultRelayIfEmpty();
      expect(await isar.relayModels.count(), 1);
    });

    test('promotes a pre-existing NON-system row at the default url '
        'by replacing it with a system row', () async {
      await seedRelay(isar, AppConstants.kUniunBackend,
          read: false, isSystem: false);
      await repo.insertDefaultRelayIfEmpty();
      final row = (await isar.relayModels.where().findAll()).single;
      expect(row.isSystem, isTrue);
      expect(row.read, isTrue);
    });

    test('leaves an existing system row untouched', () async {
      await seedRelay(isar, AppConstants.kUniunBackend,
          status: RelayStatus.connected, isSystem: true);
      await repo.insertDefaultRelayIfEmpty();
      final row = (await isar.relayModels.where().findAll()).single;
      expect(row.status, RelayStatus.connected);
    });

    test('does not disturb unrelated user relays', () async {
      await seedRelay(isar, 'wss://mine');
      await repo.insertDefaultRelayIfEmpty();
      expect(await isar.relayModels.count(), 2);
    });
  });
}
