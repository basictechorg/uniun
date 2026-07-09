import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/data/repositories/source_label_repository_impl.dart';

import '../../_helpers/isar_test_harness.dart';

/// Covers: SourceLabelRepositoryImpl.resolveMany — public/private name
/// resolution, generic fallbacks for unknown or empty names, kind-1 omission,
/// and batching over a mixed input.
void main() {
  late Isar isar;
  late SourceLabelRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = SourceLabelRepositoryImpl(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  ({String eventId, String? groupId, String? privateGroupId}) item(
    String eventId, {
    String? groupId,
    String? privateGroupId,
  }) =>
      (eventId: eventId, groupId: groupId, privateGroupId: privateGroupId);

  test('empty input → empty map', () async {
    expect(await repo.resolveMany(const []), isEmpty);
  });

  test('kind-1 item (no source ids) emits no entry', () async {
    final out = await repo.resolveMany([item('feed-note')]);
    expect(out, isEmpty);
  });

  test('public group resolves to its stored name', () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(groupSeed('g-1')..name = 'Design Talk');
    });
    final out = await repo.resolveMany([item('ev', groupId: 'g-1')]);
    expect(out, {'ev': 'Design Talk'});
  });

  test('unknown public group falls back to "group"', () async {
    final out = await repo.resolveMany([item('ev', groupId: 'nowhere')]);
    expect(out, {'ev': 'group'});
  });

  test('public group with empty name falls back to "group"', () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(groupSeed('g-1')..name = '');
    });
    final out = await repo.resolveMany([item('ev', groupId: 'g-1')]);
    expect(out, {'ev': 'group'});
  });

  test('private group resolves to its stored name', () async {
    await isar.writeTxn(() async {
      await isar.privateGroupModels
          .put(privateGroupSeed('pg-1')..name = 'Secret Base');
    });
    final out =
        await repo.resolveMany([item('ev', privateGroupId: 'pg-1')]);
    expect(out, {'ev': 'Secret Base'});
  });

  test('unknown private group falls back to "private"', () async {
    final out =
        await repo.resolveMany([item('ev', privateGroupId: 'ghost')]);
    expect(out, {'ev': 'private'});
  });

  test('groupId wins when both source ids are set (impossible in practice)',
      () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(groupSeed('g-1')..name = 'Public');
      await isar.privateGroupModels
          .put(privateGroupSeed('pg-1')..name = 'Private');
    });
    final out = await repo
        .resolveMany([item('ev', groupId: 'g-1', privateGroupId: 'pg-1')]);
    expect(out, {'ev': 'Public'});
  });

  test('mixed batch resolves every entry in two queries worth of lookups',
      () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(groupSeed('g-1')..name = 'Alpha');
      await isar.privateGroupModels
          .put(privateGroupSeed('pg-1')..name = 'Beta');
    });
    final out = await repo.resolveMany([
      item('e1', groupId: 'g-1'),
      item('e2', privateGroupId: 'pg-1'),
      item('e3', groupId: 'missing'),
      item('e4'),
      item('e5', groupId: 'g-1'),
    ]);
    expect(out, {
      'e1': 'Alpha',
      'e2': 'Beta',
      'e3': 'group',
      'e5': 'Alpha',
    });
  });

  test('unicode group names pass through untouched', () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(groupSeed('g-1')..name = '🐉 设计 مرحبا');
    });
    final out = await repo.resolveMany([item('ev', groupId: 'g-1')]);
    expect(out['ev'], '🐉 设计 مرحبا');
  });
}
