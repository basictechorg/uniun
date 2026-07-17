import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/repositories/group_repository_impl.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/mesh_test_helpers.dart';
import '../../_helpers/stub_user_repository.dart';

/// Covers: GroupRepositoryImpl save (upsert + tombstone revive + mesh event
/// stamping), out-of-order Kind-41 metadata guard, and lookups.
void main() {
  stubSecureStorageChannel();

  late Isar isar;
  late GroupRepositoryImpl repo;

  GroupRepositoryImpl withSigner(MeshEventSigner signer) =>
      GroupRepositoryImpl(isar: isar, signer: signer);

  setUp(() async {
    isar = await openTestIsar();
    repo = withSigner(MeshEventSigner(StubUserRepository()..keys = null));
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('saveGroup', () {
    test('creates a row and returns the domain entity', () async {
      final r = await repo.saveGroup(aGroup(
        groupId: 'g-1',
        name: 'General',
        relays: ['wss://r1', 'wss://r2'],
        createdAt: 1720000000,
        updatedAt: 1720000500,
      ));
      expect(r.isRight(), isTrue);
      final e = r.getOrElse(() => throw 'unreachable');
      expect(e.groupId, 'g-1');
      expect(e.name, 'General');
      expect(e.relays, ['wss://r1', 'wss://r2']);

      final rows = await isar.groupModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.updatedAt, 1720000500);
    });

    test('re-save of the same groupId upserts in place — no duplicate row',
        () async {
      await repo.saveGroup(aGroup(groupId: 'g-1', name: 'v1'));
      final firstIsarId =
          (await isar.groupModels.where().findAll()).single.id;

      await repo.saveGroup(aGroup(groupId: 'g-1', name: 'v2'));
      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.id, firstIsarId);
      expect(row.name, 'v2');
    });

    test('re-saving a tombstoned group revives the membership', () async {
      await isar.writeTxn(() async {
        await isar.groupModels
            .put(groupSeed('g-1', removedAt: DateTime(2026, 1, 1)));
      });

      final r = await repo.saveGroup(aGroup(groupId: 'g-1'));
      expect(r.isRight(), isTrue);
      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.removedAt, isNull);
    });

    test('logged-out signer leaves signedNostrEvent null (write still lands)',
        () async {
      final r = await repo.saveGroup(aGroup(groupId: 'g-1'));
      expect(r.isRight(), isTrue);
      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.signedNostrEvent, isNull);
    });

    test('logged-in signer stamps a verifiable Kind-30540 mesh snapshot',
        () async {
      final me = MeshIdentity.generate();
      repo = withSigner(MeshEventSigner(StubUserRepository()
        ..keys = (privkeyHex: me.privkey, pubkeyHex: me.pubkey)));

      await repo.saveGroup(aGroup(groupId: 'g-1', name: 'General'));

      final row = (await isar.groupModels.where().findAll()).single;
      final record = await me.codec.openRecord(row.signedNostrEvent!);
      expect(record.kind, MeshEventKinds.group);
      expect(record.dTag, 'g-1');
      expect(record.state, MeshRecordState.active);
      expect(record.content['name'], 'General');
    });

    test('unicode / emoji / RTL metadata round-trips intact', () async {
      await repo.saveGroup(aGroup(
        groupId: 'g-1',
        name: Content.emoji,
        about: Content.unicode,
      ));
      final e = (await repo.getGroupById('g-1'))
          .getOrElse(() => throw 'unreachable');
      expect(e.name, Content.emoji);
      expect(e.about, Content.unicode);
    });
  });

  group('updateGroupMetadata', () {
    test('unknown group → Left(notFound)', () async {
      final r = await repo.updateGroupMetadata(
          'nope', 'meta-1', 1720001000, 'n', 'a', 'p');
      expect(r.isLeft(), isTrue);
    });

    test('newer Kind-41 applies name/about/picture and advances the cursor',
        () async {
      await repo.saveGroup(aGroup(groupId: 'g-1', updatedAt: 1720000000));

      final r = await repo.updateGroupMetadata(
          'g-1', 'meta-1', 1720001000, 'Renamed', 'new about', 'pic.png');
      expect(r.isRight(), isTrue);

      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.name, 'Renamed');
      expect(row.about, 'new about');
      expect(row.picture, 'pic.png');
      expect(row.updatedAt, 1720001000);
      expect(row.lastMetaEvent, 'meta-1');
    });

    test('out-of-order Kind-41 (created_at <= cursor) is a silent no-op',
        () async {
      await repo.saveGroup(
          aGroup(groupId: 'g-1', name: 'Current', updatedAt: 1720002000));

      // Strictly older, then exactly-equal — both must be dropped.
      for (final stale in [1720001000, 1720002000]) {
        final r = await repo.updateGroupMetadata(
            'g-1', 'meta-stale', stale, 'Stale', 'a', 'p');
        expect(r.isRight(), isTrue);
        expect(r.getOrElse(() => throw 'unreachable').name, 'Current');
      }
      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.name, 'Current');
      expect(row.lastMetaEvent, isNull);
    });

    test('re-signs the mesh snapshot so peers get the new metadata',
        () async {
      final me = MeshIdentity.generate();
      repo = withSigner(MeshEventSigner(StubUserRepository()
        ..keys = (privkeyHex: me.privkey, pubkeyHex: me.pubkey)));
      await repo.saveGroup(aGroup(groupId: 'g-1', updatedAt: 1720000000));

      await repo.updateGroupMetadata(
          'g-1', 'meta-1', 1720001000, 'Renamed', 'a', 'p');

      final row = (await isar.groupModels.where().findAll()).single;
      final record = await me.codec.openRecord(row.signedNostrEvent!);
      expect(record.content['name'], 'Renamed');
      expect(record.content['lastMetaEvent'], 'meta-1');
    });

    test('tombstoned group: metadata updates but the removed-state mesh '
        'event is NOT overwritten with an active one', () async {
      await isar.writeTxn(() async {
        await isar.groupModels.put(groupSeed('g-1',
            removedAt: DateTime(2026, 1, 1),
            signedNostrEvent: 'removed-snapshot',
            updatedAt: 1720000000));
      });

      final r = await repo.updateGroupMetadata(
          'g-1', 'meta-1', 1720001000, 'Renamed', 'a', 'p');
      expect(r.isRight(), isTrue);

      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.name, 'Renamed');
      expect(row.signedNostrEvent, 'removed-snapshot');
      expect(row.removedAt, isNotNull);
    });

    test('logged-out signer keeps the previous mesh snapshot instead of '
        'blanking it', () async {
      await isar.writeTxn(() async {
        await isar.groupModels.put(groupSeed('g-1',
            signedNostrEvent: 'old-snapshot', updatedAt: 1720000000));
      });

      await repo.updateGroupMetadata(
          'g-1', 'meta-1', 1720001000, 'Renamed', 'a', 'p');
      final row = (await isar.groupModels.where().findAll()).single;
      expect(row.signedNostrEvent, 'old-snapshot');
    });
  });

  group('getGroups / getGroupById', () {
    test('empty database → Right(empty)', () async {
      final r = await repo.getGroups();
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw 'unreachable'), isEmpty);
    });

    test('returns every stored group', () async {
      await repo.saveGroup(aGroup(groupId: 'g-1'));
      await repo.saveGroup(aGroup(groupId: 'g-2'));

      final r = await repo.getGroups();
      final ids = r
          .getOrElse(() => throw 'unreachable')
          .map((g) => g.groupId)
          .toSet();
      expect(ids, {'g-1', 'g-2'});
    });

    test('getGroupById finds the row; unknown id → Left(notFound)', () async {
      await repo.saveGroup(aGroup(groupId: 'g-1', name: 'General'));

      final found = await repo.getGroupById('g-1');
      expect(found.getOrElse(() => throw 'unreachable').name, 'General');
      expect((await repo.getGroupById('nope')).isLeft(), isTrue);
    });
  });
}
