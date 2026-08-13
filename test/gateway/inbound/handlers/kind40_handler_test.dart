import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind40_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../../_helpers/isar_test_harness.dart';

VerifiedNostrEvent _event({
  required String id,
  required String pubkey,
  int createdAt = 1_700_000_000,
  required String content,
}) {
  return VerifiedNostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 40,
    tags: const [],
    content: content,
    sig: 'sig',
    raw: {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 40,
      'tags': const [],
      'content': content,
      'sig': 'sig',
    },
  );
}

Future<void> _seedGroup(Isar isar, {required String groupId}) {
  return isar.writeTxn(() async {
    await isar.groupModels.put(
      GroupModel()
        ..groupId = groupId
        ..creatorPubKey = 'placeholder'
        ..name = 'old name'
        ..about = 'old about'
        ..picture = 'old.png'
        ..relays = const []
        ..createdAt = 0
        ..updatedAt = 0,
    );
  });
}

/// Covers: Kind40Handler's metadata field mapping (name/about/picture/relays,
/// falling back to the existing value when absent from the event JSON), the
/// not-locally-joined no-op, malformed-JSON no-op, and the mesh re-stamp
/// path (only fires with an active identity and only for a non-removed
/// group).
void main() {
  late Isar isar;
  late Keychain me;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('declares kind 40', () {
    expect(Kind40Handler().kinds, {40});
  });

  test('a group not already joined locally is a no-op', () async {
    await Kind40Handler().handle(
      _event(id: 'g1', pubkey: me.public, content: jsonEncode({'name': 'X'})),
      isar,
    );
    expect(await isar.groupModels.where().count(), 0);
  });

  test('malformed JSON content is a silent no-op', () async {
    await _seedGroup(isar, groupId: 'g1');
    await Kind40Handler()
        .handle(_event(id: 'g1', pubkey: me.public, content: 'not-json'), isar);

    final row =
        await isar.groupModels.where().groupIdEqualTo('g1').findFirst();
    expect(row!.name, 'old name'); // untouched
  });

  test('updates name/about/picture/relays and the creator pubkey', () async {
    await _seedGroup(isar, groupId: 'g1');
    await Kind40Handler().handle(
      _event(
        id: 'g1',
        pubkey: me.public,
        content: jsonEncode({
          'name': 'New Name',
          'about': 'New about',
          'picture': 'new.png',
          'relays': ['wss://a', 'wss://b'],
        }),
      ),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.creatorPubKey, me.public);
    expect(row.name, 'New Name');
    expect(row.about, 'New about');
    expect(row.picture, 'new.png');
    expect(row.relays, ['wss://a', 'wss://b']);
  });

  test('missing fields in the metadata JSON fall back to the existing '
      'value', () async {
    await _seedGroup(isar, groupId: 'g1');
    await Kind40Handler()
        .handle(_event(id: 'g1', pubkey: me.public, content: jsonEncode({})), isar);

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.name, 'old name');
    expect(row.about, 'old about');
    expect(row.picture, 'old.png');
  });

  test('with no active identity, signedNostrEvent is left untouched',
      () async {
    await _seedGroup(isar, groupId: 'g1');
    await Kind40Handler()
        .handle(_event(id: 'g1', pubkey: me.public, content: jsonEncode({'name': 'X'})), isar);

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.signedNostrEvent, isNull);
  });

  test('with an active identity, re-stamps signedNostrEvent for a '
      'non-removed group', () async {
    await _seedGroup(isar, groupId: 'g1');
    final handler = Kind40Handler(activePubkey: me.public, activePrivkey: me.private);
    await handler.handle(
      _event(id: 'g1', pubkey: me.public, content: jsonEncode({'name': 'X'})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.signedNostrEvent, isNotNull);
  });

  test('a removed group is not re-stamped even with an active identity',
      () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(
        GroupModel()
          ..groupId = 'g1'
          ..creatorPubKey = 'placeholder'
          ..name = 'old'
          ..about = ''
          ..picture = ''
          ..relays = const []
          ..createdAt = 0
          ..updatedAt = 0
          ..removedAt = DateTime(2026, 1, 1),
      );
    });
    final handler = Kind40Handler(activePubkey: me.public, activePrivkey: me.private);
    await handler.handle(
      _event(id: 'g1', pubkey: me.public, content: jsonEncode({'name': 'X'})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.signedNostrEvent, isNull);
  });
}
