import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/gateway/outbound/event_router.dart';
import 'package:uniun/gateway/outbound/routing/dm_routing_strategy.dart';
import 'package:uniun/gateway/outbound/routing/group_routing_strategy.dart';
import 'package:uniun/gateway/outbound/routing/private_group_routing_strategy.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

import '../../../_helpers/isar_test_harness.dart';

EventQueueModel _queueRow({
  String eventId = 'e1',
  int kind = 1,
  String? rootEventId,
  String? hTag,
  List<String> pTagRefs = const [],
}) {
  return EventQueueModel()
    ..eventId = eventId
    ..authorPubkey = 'a'
    ..sig = 's'
    ..content = 'c'
    ..kind = kind
    ..eTagRefs = const []
    ..rootEventId = rootEventId
    ..pTagRefs = pTagRefs
    ..tTags = const []
    ..hTag = hTag
    ..created = DateTime.now()
    ..enqueuedAt = DateTime.now();
}

/// Covers: EventRouter's first-match-wins strategy dispatch and the
/// null-fanout default when no strategy matches; DmRoutingStrategy's
/// kind-1059 gate, first-p-tag lookup, and fallback when no conversation
/// row (or an empty relay list) is found; GroupRoutingStrategy's kind-40
/// (event id = group id) vs. kind-41..44 (root e-tag) id resolution and its
/// fallback; PrivateGroupRoutingStrategy's h-tag-based lookup across every
/// Marmot kind plus the private-group-message kind, and its fallback.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('EventRouter', () {
    test('returns null (all main relays) when no strategy matches', () async {
      final router = EventRouter(isar: isar, strategies: const []);
      final targets = await router.resolveTargets(_queueRow());
      expect(targets, isNull);
    });

    test('dispatches to the first matching strategy', () async {
      final router = EventRouter(
        isar: isar,
        strategies: [_AlwaysMatches(['wss://picked'])],
      );
      final targets = await router.resolveTargets(_queueRow());
      expect(targets, ['wss://picked']);
    });

    test('a later strategy is never consulted once an earlier one matches',
        () async {
      final router = EventRouter(
        isar: isar,
        strategies: [
          _AlwaysMatches(['wss://first']),
          _AlwaysMatches(['wss://second']),
        ],
      );
      final targets = await router.resolveTargets(_queueRow());
      expect(targets, ['wss://first']);
    });
  });

  group('DmRoutingStrategy', () {
    final strategy = DmRoutingStrategy();

    test('matches only kind 1059', () {
      expect(strategy.matches(_queueRow(kind: 1059)), isTrue);
      expect(strategy.matches(_queueRow(kind: 1)), isFalse);
    });

    test('an empty pTagRefs falls back to null', () async {
      final targets =
          await strategy.resolveTargets(_queueRow(kind: 1059, pTagRefs: const []), isar);
      expect(targets, isNull);
    });

    test('no matching conversation row falls back to null', () async {
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 1059, pTagRefs: const ['unknown-pubkey']),
        isar,
      );
      expect(targets, isNull);
    });

    test('a conversation with an empty relay list falls back to null',
        () async {
      await isar.writeTxn(() async {
        await isar.dmConversationModels.put(
          DmConversationModel()
            ..otherPubkey = 'peer1'
            ..relays = const [],
        );
      });
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 1059, pTagRefs: const ['peer1']),
        isar,
      );
      expect(targets, isNull);
    });

    test('resolves the conversation\'s stored relays for the first p-tag',
        () async {
      await isar.writeTxn(() async {
        await isar.dmConversationModels.put(
          DmConversationModel()
            ..otherPubkey = 'peer1'
            ..relays = ['wss://dm-relay'],
        );
      });
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 1059, pTagRefs: const ['peer1', 'ignored-second']),
        isar,
      );
      expect(targets, ['wss://dm-relay']);
    });
  });

  group('GroupRoutingStrategy', () {
    final strategy = GroupRoutingStrategy();

    test('matches kinds 40 through 44 only', () {
      expect(strategy.matches(_queueRow(kind: 40)), isTrue);
      expect(strategy.matches(_queueRow(kind: 44)), isTrue);
      expect(strategy.matches(_queueRow(kind: 39)), isFalse);
      expect(strategy.matches(_queueRow(kind: 45)), isFalse);
    });

    test('kind 40 uses the event id itself as the group id', () async {
      await isar.writeTxn(() async {
        await isar.groupModels.put(
          GroupModel()
            ..groupId = 'g1'
            ..creatorPubKey = 'c'
            ..name = 'g'
            ..about = ''
            ..picture = ''
            ..relays = ['wss://group-relay']
            ..createdAt = 0
            ..updatedAt = 0,
        );
      });
      final targets =
          await strategy.resolveTargets(_queueRow(kind: 40, eventId: 'g1'), isar);
      expect(targets, ['wss://group-relay']);
    });

    test('kind 41-44 uses the root e-tag as the group id', () async {
      await isar.writeTxn(() async {
        await isar.groupModels.put(
          GroupModel()
            ..groupId = 'g1'
            ..creatorPubKey = 'c'
            ..name = 'g'
            ..about = ''
            ..picture = ''
            ..relays = ['wss://group-relay']
            ..createdAt = 0
            ..updatedAt = 0,
        );
      });
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 42, eventId: 'msg-1', rootEventId: 'g1'),
        isar,
      );
      expect(targets, ['wss://group-relay']);
    });

    test('a null groupId (missing rootEventId on non-40 kinds) falls back '
        'to null', () async {
      final targets = await strategy.resolveTargets(_queueRow(kind: 42), isar);
      expect(targets, isNull);
    });

    test('no matching GroupModel falls back to null', () async {
      final targets =
          await strategy.resolveTargets(_queueRow(kind: 40, eventId: 'ghost'), isar);
      expect(targets, isNull);
    });

    test('a group with an empty relay list falls back to null', () async {
      await isar.writeTxn(() async {
        await isar.groupModels.put(
          GroupModel()
            ..groupId = 'g1'
            ..creatorPubKey = 'c'
            ..name = 'g'
            ..about = ''
            ..picture = ''
            ..relays = const []
            ..createdAt = 0
            ..updatedAt = 0,
        );
      });
      final targets =
          await strategy.resolveTargets(_queueRow(kind: 40, eventId: 'g1'), isar);
      expect(targets, isNull);
    });
  });

  group('PrivateGroupRoutingStrategy', () {
    final strategy = PrivateGroupRoutingStrategy();

    test('matches every Marmot kind plus the private-group-message kind',
        () {
      for (final k in [9002, 9021, 9022, 9023, 9024, 9025]) {
        expect(strategy.matches(_queueRow(kind: k)), isTrue, reason: 'kind $k');
      }
      expect(strategy.matches(_queueRow(kind: kPrivateGroupKind)), isTrue);
      expect(strategy.matches(_queueRow(kind: 1)), isFalse);
    });

    test('a null hTag falls back to null', () async {
      final targets = await strategy.resolveTargets(_queueRow(kind: 9023), isar);
      expect(targets, isNull);
    });

    test('no matching PrivateGroupModel falls back to null', () async {
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 9023, hTag: 'ghost'),
        isar,
      );
      expect(targets, isNull);
    });

    test('resolves the private group\'s stored relays via hTag', () async {
      await isar.writeTxn(() async {
        await isar.privateGroupModels.put(
          PrivateGroupModel()
            ..groupId = 'pg1'
            ..mlsGroupId = 'mls-pg1'
            ..relays = ['wss://pg-relay']
            ..name = 'pg'
            ..description = ''
            ..adminPubkey = 'admin',
        );
      });
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 9023, hTag: 'pg1'),
        isar,
      );
      expect(targets, ['wss://pg-relay']);
    });

    test('a private group with an empty relay list falls back to null',
        () async {
      await isar.writeTxn(() async {
        await isar.privateGroupModels.put(
          PrivateGroupModel()
            ..groupId = 'pg1'
            ..mlsGroupId = 'mls-pg1'
            ..relays = const []
            ..name = 'pg'
            ..description = ''
            ..adminPubkey = 'admin',
        );
      });
      final targets = await strategy.resolveTargets(
        _queueRow(kind: 9023, hTag: 'pg1'),
        isar,
      );
      expect(targets, isNull);
    });
  });
}

class _AlwaysMatches implements RoutingStrategy {
  _AlwaysMatches(this._targets);
  final List<String> _targets;

  @override
  bool matches(EventQueueModel event) => true;

  @override
  Future<List<String>?> resolveTargets(EventQueueModel event, Isar isar) async =>
      _targets;
}
