import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind41_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../../_helpers/isar_test_harness.dart';

VerifiedNostrEvent _event({
  required String id,
  required String pubkey,
  int createdAt = 1_700_000_100,
  List<List<String>> tags = const [],
  required String content,
}) {
  return VerifiedNostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 41,
    tags: tags,
    content: content,
    sig: 'sig',
    raw: {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 41,
      'tags': tags,
      'content': content,
      'sig': 'sig',
    },
  );
}

Future<void> _seedGroup(
  Isar isar, {
  required String groupId,
  required String creatorPubKey,
  int updatedAt = 1_700_000_000,
}) {
  return isar.writeTxn(() async {
    await isar.groupModels.put(
      GroupModel()
        ..groupId = groupId
        ..creatorPubKey = creatorPubKey
        ..name = 'old name'
        ..about = 'old about'
        ..picture = 'old.png'
        ..relays = const []
        ..createdAt = 0
        ..updatedAt = updatedAt,
    );
  });
}

/// Covers: Kind41Handler's e-tag groupId extraction (missing → no-op),
/// creator-only enforcement, staleness rejection (createdAt <= existing
/// updatedAt), malformed-JSON no-op, metadata field mapping with
/// fallback-to-existing, updatedAt/lastMetaEvent bookkeeping, and the mesh
/// re-stamp path gating (active identity + non-removed group).
void main() {
  late Isar isar;
  late Keychain creator;
  late Keychain someoneElse;

  setUp(() async {
    isar = await openTestIsar();
    creator = Keychain.generate();
    someoneElse = Keychain.generate();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('declares kind 41', () {
    expect(Kind41Handler().kinds, {41});
  });

  test('missing e-tag groupId is a no-op', () async {
    await Kind41Handler().handle(
      _event(id: 'm1', pubkey: creator.public, content: jsonEncode({'name': 'X'})),
      isar,
    );
    // Nothing to assert on Isar directly; just confirm no throw and no group
    // exists to have been mutated.
    expect(await isar.groupModels.where().count(), 0);
  });

  test('a group not locally known is a no-op', () async {
    await Kind41Handler().handle(
      _event(id: 'm1', pubkey: creator.public, tags: [
        ['e', 'g1'],
      ], content: jsonEncode({'name': 'X'})),
      isar,
    );
    expect(await isar.groupModels.where().count(), 0);
  });

  test('an update from a non-creator pubkey is rejected', () async {
    await _seedGroup(isar, groupId: 'g1', creatorPubKey: creator.public);
    await Kind41Handler().handle(
      _event(id: 'm1', pubkey: someoneElse.public, tags: [
        ['e', 'g1'],
      ], content: jsonEncode({'name': 'Hijacked'})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.name, 'old name');
  });

  test('a createdAt not strictly newer than the group\'s updatedAt is '
      'rejected', () async {
    await _seedGroup(
      isar,
      groupId: 'g1',
      creatorPubKey: creator.public,
      updatedAt: 1_700_000_100,
    );
    await Kind41Handler().handle(
      _event(
        id: 'm1',
        pubkey: creator.public,
        createdAt: 1_700_000_100, // equal, not newer
        tags: [
          ['e', 'g1'],
        ],
        content: jsonEncode({'name': 'Stale'}),
      ),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.name, 'old name');
  });

  test('malformed JSON content is a silent no-op', () async {
    await _seedGroup(isar, groupId: 'g1', creatorPubKey: creator.public);
    await Kind41Handler().handle(
      _event(id: 'm1', pubkey: creator.public, tags: [
        ['e', 'g1'],
      ], content: 'not-json'),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.name, 'old name');
  });

  test('a valid creator update writes name/about/picture/relays and '
      'bookkeeping', () async {
    await _seedGroup(isar, groupId: 'g1', creatorPubKey: creator.public);
    await Kind41Handler().handle(
      _event(
        id: 'meta-evt',
        pubkey: creator.public,
        tags: [
          ['e', 'g1'],
        ],
        content: jsonEncode({
          'name': 'New Name',
          'about': 'New about',
          'picture': 'new.png',
          'relays': ['wss://a'],
        }),
      ),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.name, 'New Name');
    expect(row.about, 'New about');
    expect(row.picture, 'new.png');
    expect(row.relays, ['wss://a']);
    expect(row.updatedAt, 1_700_000_100);
    expect(row.lastMetaEvent, 'meta-evt');
  });

  test('missing fields in the metadata JSON fall back to the existing '
      'value', () async {
    await _seedGroup(isar, groupId: 'g1', creatorPubKey: creator.public);
    await Kind41Handler().handle(
      _event(id: 'm1', pubkey: creator.public, tags: [
        ['e', 'g1'],
      ], content: jsonEncode({})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.name, 'old name');
    expect(row.about, 'old about');
    expect(row.picture, 'old.png');
  });

  test('with an active identity, re-stamps signedNostrEvent for a '
      'non-removed group', () async {
    await _seedGroup(isar, groupId: 'g1', creatorPubKey: creator.public);
    final handler =
        Kind41Handler(activePubkey: creator.public, activePrivkey: creator.private);
    await handler.handle(
      _event(id: 'm1', pubkey: creator.public, tags: [
        ['e', 'g1'],
      ], content: jsonEncode({'name': 'X'})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.signedNostrEvent, isNotNull);
  });

  test('with no active identity, signedNostrEvent is left untouched',
      () async {
    await _seedGroup(isar, groupId: 'g1', creatorPubKey: creator.public);
    await Kind41Handler().handle(
      _event(id: 'm1', pubkey: creator.public, tags: [
        ['e', 'g1'],
      ], content: jsonEncode({'name': 'X'})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.signedNostrEvent, isNull);
  });

  test('a removed group is not re-stamped even with an active identity',
      () async {
    await isar.writeTxn(() async {
      await isar.groupModels.put(
        GroupModel()
          ..groupId = 'g1'
          ..creatorPubKey = creator.public
          ..name = 'old'
          ..about = ''
          ..picture = ''
          ..relays = const []
          ..createdAt = 0
          ..updatedAt = 1_700_000_000
          ..removedAt = DateTime(2026, 1, 1),
      );
    });
    final handler =
        Kind41Handler(activePubkey: creator.public, activePrivkey: creator.private);
    await handler.handle(
      _event(id: 'm1', pubkey: creator.public, tags: [
        ['e', 'g1'],
      ], content: jsonEncode({'name': 'X'})),
      isar,
    );

    final row =
        (await isar.groupModels.where().groupIdEqualTo('g1').findFirst())!;
    expect(row.signedNostrEvent, isNull);
  });
}
