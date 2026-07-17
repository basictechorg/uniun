import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/media/media_cache_model.dart';
import 'package:uniun/data/models/private_group_join_request_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/data/repositories/e2ee_group_repository_impl.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: E2EEGroupRepositoryImpl group CRUD + watch streams, private-group
/// message scoping with attachment cache enrichment, and the pending
/// join-request queue (unhandled-only, timestamp order).
void main() {
  late Isar isar;
  late E2EEGroupRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = E2EEGroupRepositoryImpl(isar, NoteAttachmentsEnricher(isar: isar));
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('groups', () {
    test('saveGroup / getGroups round-trips every field', () async {
      await repo.saveGroup(aPrivateGroup(
        groupId: 'pg-1',
        name: 'Secret',
        description: 'the inner circle',
        relays: ['wss://r1'],
        adminPubkey: kAlicePub,
      ));

      final groups = await repo.getGroups();
      expect(groups, hasLength(1));
      final g = groups.single;
      expect(g.groupId, 'pg-1');
      expect(g.mlsGroupId, 'mls_pg-1');
      expect(g.name, 'Secret');
      expect(g.description, 'the inner circle');
      expect(g.relays, ['wss://r1']);
      expect(g.adminPubkey, kAlicePub);
    });

    test('saveGroup with the entity\'s Isar id updates in place', () async {
      await repo.saveGroup(aPrivateGroup(groupId: 'pg-1', name: 'v1'));
      final existing = (await repo.getGroups()).single;

      await repo.saveGroup(aPrivateGroup(
          id: existing.id, groupId: 'pg-1', name: 'v2'));

      final rows = await isar.privateGroupModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'v2');
    });

    test('deleteGroup removes only the targeted group', () async {
      await repo.saveGroup(aPrivateGroup(groupId: 'pg-1'));
      await repo.saveGroup(aPrivateGroup(groupId: 'pg-2'));

      await repo.deleteGroup('pg-1');

      expect((await repo.getGroups()).map((g) => g.groupId), ['pg-2']);
      // Deleting an unknown id is a no-op, not an error.
      await repo.deleteGroup('nope');
      expect(await isar.privateGroupModels.count(), 1);
    });

    test('watchGroups fires immediately with current state, then on change',
        () async {
      await repo.saveGroup(aPrivateGroup(groupId: 'pg-1'));

      final emissions = repo.watchGroups().take(2).toList();
      // Trigger the second emission after the watcher is attached.
      await Future<void>.delayed(Duration.zero);
      await repo.saveGroup(aPrivateGroup(groupId: 'pg-2'));

      final frames = await emissions;
      expect(frames.first.map((g) => g.groupId), ['pg-1']);
      expect(frames.last.map((g) => g.groupId).toSet(), {'pg-1', 'pg-2'});
    });
  });

  group('messages', () {
    test('only this group\'s Kind-9023 rows, oldest first — other private '
        'groups, public groups and feed notes stay invisible', () async {
      await seedNoteRow(isar, 'pm-2',
          kind: kPrivateGroupKind,
          privateGroupId: 'pg-1',
          created: tNow.add(const Duration(minutes: 1)));
      await seedNoteRow(isar, 'pm-1',
          kind: kPrivateGroupKind, privateGroupId: 'pg-1', created: tNow);
      await seedNoteRow(isar, 'other-group',
          kind: kPrivateGroupKind, privateGroupId: 'pg-2');
      await seedNoteRow(isar, 'public-group',
          kind: kGroupMessageKind, groupId: 'pg-1');
      await seedNoteRow(isar, 'feed-note');

      final msgs = await repo.getMessages('pg-1');
      expect(msgs.map((e) => e.id).toList(), ['pm-1', 'pm-2']);
      expect(msgs.first.sourcePrivateGroupId, 'pg-1');
    });

    test('attachment cache state is joined onto returned messages', () async {
      await seedNoteRow(isar, 'pm-media',
          kind: kPrivateGroupKind,
          privateGroupId: 'pg-1',
          attachments: [mediaAttachmentRow(sha256: 'sha-img')]);
      await isar.writeTxn(() async {
        await isar.mediaCacheModels
            .put(mediaCacheRow('sha-img', localPath: '/data/media/sha-img.jpg'));
      });

      final msg = (await repo.getMessages('pg-1')).single;
      expect(msg.attachments.single.localPath, '/data/media/sha-img.jpg');
    });

    test('watchMessages emits the enriched list when a message lands',
        () async {
      final emissions = repo.watchMessages('pg-1').take(2).toList();
      await Future<void>.delayed(Duration.zero);
      await seedNoteRow(isar, 'pm-1',
          kind: kPrivateGroupKind, privateGroupId: 'pg-1');

      final frames = await emissions;
      expect(frames.first, isEmpty);
      expect(frames.last.map((e) => e.id), ['pm-1']);
    });

    test('unicode content round-trips intact', () async {
      await seedNoteRow(isar, 'pm-uni',
          kind: kPrivateGroupKind,
          privateGroupId: 'pg-1',
          content: Content.emoji);
      expect((await repo.getMessages('pg-1')).single.content, Content.emoji);
    });
  });

  group('join requests', () {
    test('returns only UNHANDLED requests for the group, oldest first',
        () async {
      await isar.writeTxn(() async {
        await isar.privateGroupJoinRequestModels.putAll([
          joinRequestRow('req-late',
              groupId: 'pg-1', timestamp: tNow.add(const Duration(hours: 1))),
          joinRequestRow('req-early', groupId: 'pg-1', timestamp: tNow),
          joinRequestRow('req-done',
              groupId: 'pg-1', handled: true, timestamp: tT0),
          joinRequestRow('req-other', groupId: 'pg-2'),
        ]);
      });

      final pending = await repo.getJoinRequests('pg-1');
      expect(pending.map((r) => r.eventId).toList(),
          ['req-early', 'req-late']);
      expect(pending.first.keyPackageB64, 'a2V5cGFja2FnZQ==');
    });

    test('watchJoinRequests drops a request from the stream once handled',
        () async {
      await isar.writeTxn(() async {
        await isar.privateGroupJoinRequestModels
            .put(joinRequestRow('req-1', groupId: 'pg-1'));
      });

      final emissions = repo.watchJoinRequests('pg-1').take(2).toList();
      await Future<void>.delayed(Duration.zero);
      await isar.writeTxn(() async {
        final row = (await isar.privateGroupJoinRequestModels
            .where()
            .eventIdEqualTo('req-1')
            .findFirst())!;
        row.handled = true;
        await isar.privateGroupJoinRequestModels.put(row);
      });

      final frames = await emissions;
      expect(frames.first.map((r) => r.eventId), ['req-1']);
      expect(frames.last, isEmpty);
    });
  });
}
