import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind3_contact_list_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../../_helpers/isar_test_harness.dart';

const _kSelf = 'self-pub-hex';
const _kOther = 'other-pub-hex';

VerifiedNostrEvent _event({
  required String id,
  String pubkey = _kSelf,
  int createdAt = 1_700_000_100,
  List<List<String>> tags = const [],
}) {
  return VerifiedNostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 3,
    tags: tags,
    content: '',
    sig: 'sig',
    raw: {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 3,
      'tags': tags,
      'content': '',
      'sig': 'sig',
    },
  );
}

/// Covers: Kind3ContactListHandler's no-active-user and foreign-author
/// no-ops, tag parsing (relay hint + petname, malformed/empty p-tags
/// skipped), staleness rejection against the max lastKind3CreatedAt across
/// existing rows, diff-based replace (new follows added, dropped follows
/// tombstoned via removedAt, survivors keep their original followedAt), and
/// resurrection of a previously-tombstoned pubkey.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('declares kind 3', () {
    expect(Kind3ContactListHandler(activePubkey: _kSelf).kinds, {3});
  });

  test('no active user is a no-op', () async {
    await Kind3ContactListHandler(activePubkey: null).handle(
      _event(id: 'e1', tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    expect(await isar.followedUserModels.where().count(), 0);
  });

  test('an event authored by someone other than the active user is '
      'ignored', () async {
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', pubkey: _kOther, tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    expect(await isar.followedUserModels.where().count(), 0);
  });

  test('parses relay hint and petname, and skips malformed/empty p-tags',
      () async {
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', tags: [
        ['p', _kOther, 'wss://relay.example', 'Bob'],
        ['p', ''],
        ['e', 'not-a-p-tag'],
        [],
      ]),
      isar,
    );

    final row = await isar.followedUserModels
        .where()
        .pubkeyHexEqualTo(_kOther)
        .findFirst();
    expect(row, isNotNull);
    expect(row!.relayHint, 'wss://relay.example');
    expect(row.petname, 'Bob');
  });

  test('a stale event (createdAt not after the max lastKind3CreatedAt) is '
      'rejected', () async {
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', createdAt: 1_700_000_100, tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e2', createdAt: 1_700_000_000, tags: [
        ['p', 'someone-new'],
      ]),
      isar,
    );

    expect(await isar.followedUserModels.where().count(), 1);
    expect(
      await isar.followedUserModels
          .where()
          .pubkeyHexEqualTo('someone-new')
          .count(),
      0,
    );
  });

  test('a dropped follow (present locally, absent from the new list) is '
      'tombstoned via removedAt, not deleted', () async {
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', createdAt: 1_700_000_000, tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e2', createdAt: 1_700_000_100, tags: const []),
      isar,
    );

    final row = await isar.followedUserModels
        .where()
        .pubkeyHexEqualTo(_kOther)
        .findFirst();
    expect(row, isNotNull);
    expect(row!.removedAt, isNotNull);
  });

  test('a surviving follow keeps its original followedAt across updates',
      () async {
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', createdAt: 1_700_000_000, tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    final firstFollowedAt = (await isar.followedUserModels
            .where()
            .pubkeyHexEqualTo(_kOther)
            .findFirst())!
        .followedAt;

    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e2', createdAt: 1_700_000_100, tags: [
        ['p', _kOther, '', 'NewPetname'],
      ]),
      isar,
    );

    final row = await isar.followedUserModels
        .where()
        .pubkeyHexEqualTo(_kOther)
        .findFirst();
    expect(row!.followedAt, firstFollowedAt);
    expect(row.petname, 'NewPetname');
  });

  test('the max lastKind3CreatedAt across multiple existing rows is used '
      'for the staleness check', () async {
    await isar.writeTxn(() async {
      await isar.followedUserModels.put(
        FollowedUserModel()
          ..pubkeyHex = 'p1'
          ..followedAt = DateTime(2026, 1, 1)
          ..lastKind3CreatedAt = DateTime.fromMillisecondsSinceEpoch(
              1_700_000_000 * 1000),
      );
      await isar.followedUserModels.put(
        FollowedUserModel()
          ..pubkeyHex = 'p2'
          ..followedAt = DateTime(2026, 1, 1)
          ..lastKind3CreatedAt = DateTime.fromMillisecondsSinceEpoch(
              1_700_000_200 * 1000), // the true max
      );
    });

    // Newer than p1's stamp but not newer than p2's true max → rejected.
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', createdAt: 1_700_000_100, tags: [
        ['p', 'p3'],
      ]),
      isar,
    );

    expect(
      await isar.followedUserModels.where().pubkeyHexEqualTo('p3').count(),
      0,
    );
  });

  test('a previously-tombstoned pubkey resurfacing clears removedAt',
      () async {
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e1', createdAt: 1_700_000_000, tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e2', createdAt: 1_700_000_100, tags: const []),
      isar,
    );
    var row = await isar.followedUserModels
        .where()
        .pubkeyHexEqualTo(_kOther)
        .findFirst();
    expect(row!.removedAt, isNotNull);

    await Kind3ContactListHandler(activePubkey: _kSelf).handle(
      _event(id: 'e3', createdAt: 1_700_000_200, tags: [
        ['p', _kOther],
      ]),
      isar,
    );
    row = await isar.followedUserModels
        .where()
        .pubkeyHexEqualTo(_kOther)
        .findFirst();
    expect(row!.removedAt, isNull);
  });
}
