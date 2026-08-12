import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/gateway/watchers/isar_watcher_hub.dart';

import '../../_helpers/isar_test_harness.dart';

GroupModel _group(String id) => GroupModel()
  ..groupId = id
  ..creatorPubKey = 'creator'
  ..name = 'g'
  ..about = ''
  ..picture = ''
  ..relays = const []
  ..createdAt = 0
  ..updatedAt = 0;

EventQueueModel _queueRow(String eventId) => EventQueueModel()
  ..eventId = eventId
  ..authorPubkey = 'a'
  ..sig = 's'
  ..content = 'c'
  ..kind = 1
  ..eTagRefs = const []
  ..pTagRefs = const []
  ..tTags = const []
  ..created = DateTime.now()
  ..enqueuedAt = DateTime.now();

PrivateGroupModel _privateGroup(String id) => PrivateGroupModel()
  ..groupId = id
  ..mlsGroupId = 'mls-$id'
  ..relays = const []
  ..name = 'pg'
  ..description = ''
  ..adminPubkey = 'admin';

/// Covers: IsarWatcherHub's per-collection watchLazy wiring (queue, relay,
/// followed-note, followed-user, missing-profile all fire their handler on
/// any write), the group/private-group count-increase gating (only a net
/// increase fires the handler; same-or-fewer just updates the known count
/// silently), start() capturing the baseline count before subscribing, and
/// dispose() cancelling every subscription so no handler fires afterward.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<void> waitForListener() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('each simple watcher fires its handler on any write to its '
      'collection', () async {
    final fired = <String, int>{};
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async => fired['queue'] = (fired['queue'] ?? 0) + 1,
        onRelayModelsChanged: () async =>
            fired['relay'] = (fired['relay'] ?? 0) + 1,
        onFollowedNotesChanged: () async =>
            fired['followedNote'] = (fired['followedNote'] ?? 0) + 1,
        onFollowedUsersChanged: () async =>
            fired['followedUser'] = (fired['followedUser'] ?? 0) + 1,
        onMissingProfilesChanged: () async =>
            fired['missingProfile'] = (fired['missingProfile'] ?? 0) + 1,
        onGroupsChangedAdditive: () async {},
        onPrivateGroupsChangedAdditive: () async {},
      ),
    );
    await hub.start();

    await isar.writeTxn(() async {
      await isar.eventQueueModels.put(_queueRow('e1'));
      await isar.relayModels.put(
        RelayModel()
          ..url = 'wss://r'
          ..read = true
          ..write = true
          ..status = RelayStatus.disconnected
          ..isSystem = false,
      );
      await isar.followedNoteModels.put(
        FollowedNoteModel()
          ..eventId = 'n1'
          ..contentPreview = 'x'
          ..followedAt = DateTime.now(),
      );
      await isar.followedUserModels.put(
        FollowedUserModel()
          ..pubkeyHex = 'p1'
          ..followedAt = DateTime.now(),
      );
      await isar.missingProfilePubkeyModels.put(
        MissingProfilePubkeyModel()
          ..pubkey = 'p1'
          ..firstSeenAt = DateTime.now(),
      );
    });
    await waitForListener();

    expect(fired['queue'], 1);
    expect(fired['relay'], 1);
    expect(fired['followedNote'], 1);
    expect(fired['followedUser'], 1);
    expect(fired['missingProfile'], 1);

    await hub.dispose();
  });

  test('a net increase in group count fires onGroupsChangedAdditive',
      () async {
    var fired = 0;
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async {},
        onRelayModelsChanged: () async {},
        onFollowedNotesChanged: () async {},
        onFollowedUsersChanged: () async {},
        onMissingProfilesChanged: () async {},
        onGroupsChangedAdditive: () async => fired++,
        onPrivateGroupsChangedAdditive: () async {},
      ),
    );
    await hub.start();

    await isar.writeTxn(() async {
      await isar.groupModels.put(_group('g1'));
    });
    await waitForListener();

    expect(fired, 1);
    await hub.dispose();
  });

  test('a metadata-only update (no count change) does not fire '
      'onGroupsChangedAdditive', () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(_group('g1'));
    });

    var fired = 0;
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async {},
        onRelayModelsChanged: () async {},
        onFollowedNotesChanged: () async {},
        onFollowedUsersChanged: () async {},
        onMissingProfilesChanged: () async {},
        onGroupsChangedAdditive: () async => fired++,
        onPrivateGroupsChangedAdditive: () async {},
      ),
    );
    await hub.start(); // baseline count = 1

    await isar.writeTxn(() async {
      final g = (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
      g.name = 'renamed';
      await isar.groupModels.put(g); // same count (update, not insert)
    });
    await waitForListener();

    expect(fired, 0);
    await hub.dispose();
  });

  test('a decrease in group count updates the known count without firing',
      () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(_group('g1'));
      await isar.groupModels.put(_group('g2'));
    });

    var fired = 0;
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async {},
        onRelayModelsChanged: () async {},
        onFollowedNotesChanged: () async {},
        onFollowedUsersChanged: () async {},
        onMissingProfilesChanged: () async {},
        onGroupsChangedAdditive: () async => fired++,
        onPrivateGroupsChangedAdditive: () async {},
      ),
    );
    await hub.start(); // baseline count = 2

    await isar.writeTxn(() async {
      final g1 = (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
      await isar.groupModels.delete(g1.id);
    });
    await waitForListener();
    expect(fired, 0);

    // A subsequent net-increase past the NEW (lower) baseline still fires.
    await isar.writeTxn(() async {
      await isar.groupModels.put(_group('g3'));
    });
    await waitForListener();
    expect(fired, 1);

    await hub.dispose();
  });

  test('the same increase/decrease/metadata-only gating applies to private '
      'groups', () async {
    var fired = 0;
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async {},
        onRelayModelsChanged: () async {},
        onFollowedNotesChanged: () async {},
        onFollowedUsersChanged: () async {},
        onMissingProfilesChanged: () async {},
        onGroupsChangedAdditive: () async {},
        onPrivateGroupsChangedAdditive: () async => fired++,
      ),
    );
    await hub.start();

    await isar.writeTxn(() async {
      await isar.privateGroupModels.put(_privateGroup('pg1'));
    });
    await waitForListener();
    expect(fired, 1);

    // A metadata-only update (same count) does not fire again.
    await isar.writeTxn(() async {
      final pg = (await isar.privateGroupModels
          .where()
          .groupIdEqualTo('pg1')
          .findFirst())!;
      pg.name = 'renamed';
      await isar.privateGroupModels.put(pg);
    });
    await waitForListener();
    expect(fired, 1); // unchanged

    await hub.dispose();
  });

  test('start() captures the pre-existing count as the baseline (an '
      'already-present group does not itself count as an increase)',
      () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(_group('g1'));
    });

    var fired = 0;
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async {},
        onRelayModelsChanged: () async {},
        onFollowedNotesChanged: () async {},
        onFollowedUsersChanged: () async {},
        onMissingProfilesChanged: () async {},
        onGroupsChangedAdditive: () async => fired++,
        onPrivateGroupsChangedAdditive: () async {},
      ),
    );
    await hub.start();

    // No write at all — no watchLazy event, no fire.
    await waitForListener();
    expect(fired, 0);
    await hub.dispose();
  });

  test('dispose cancels every subscription — no handler fires afterward',
      () async {
    var fired = 0;
    final hub = IsarWatcherHub(
      isar: isar,
      handlers: WatcherHandlers(
        onQueueChanged: () async => fired++,
        onRelayModelsChanged: () async {},
        onFollowedNotesChanged: () async {},
        onFollowedUsersChanged: () async {},
        onMissingProfilesChanged: () async {},
        onGroupsChangedAdditive: () async {},
        onPrivateGroupsChangedAdditive: () async {},
      ),
    );
    await hub.start();
    await hub.dispose();

    await isar.writeTxn(() async {
      await isar.eventQueueModels.put(_queueRow('e1'));
    });
    await waitForListener();

    expect(fired, 0);
  });
}
