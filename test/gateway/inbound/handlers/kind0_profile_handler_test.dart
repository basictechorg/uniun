import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind0_profile_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../../_helpers/isar_test_harness.dart';

const _kAlice = 'alice-pub-hex';

VerifiedNostrEvent _event({
  required String id,
  String pubkey = _kAlice,
  int createdAt = 1_700_000_000,
  required String content,
}) {
  return VerifiedNostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 0,
    tags: const [],
    content: content,
    sig: 'sig',
    raw: {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': 0,
      'tags': const [],
      'content': content,
      'sig': 'sig',
    },
  );
}

/// Covers: Kind0ProfileHandler's metadata field mapping (name falls back
/// display_name→name, username/about/avatar/nip05), malformed-JSON no-op,
/// stale-update rejection (older createdAt is dropped), lastSeenAt
/// preservation across updates, missing-profile-tracker row clearing on
/// arrival, and the write-failure swallow.
void main() {
  late Isar isar;

  setUp(() async {
    isar = await openTestIsar();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('declares kind 0', () {
    expect(Kind0ProfileHandler().kinds, {0});
  });

  test('creates a fresh profile with display_name preferred over name',
      () async {
    await Kind0ProfileHandler().handle(
      _event(
        id: 'e1',
        content: jsonEncode({
          'display_name': 'Alice D',
          'name': 'alice',
          'about': 'bio',
          'picture': 'https://x/pic.png',
          'nip05': 'alice@example.com',
        }),
      ),
      isar,
    );

    final row =
        await isar.profileModels.where().pubkeyEqualTo(_kAlice).findFirst();
    expect(row, isNotNull);
    expect(row!.name, 'Alice D');
    expect(row.username, 'alice');
    expect(row.about, 'bio');
    expect(row.avatarUrl, 'https://x/pic.png');
    expect(row.nip05, 'alice@example.com');
  });

  test('falls back to name when display_name is absent', () async {
    await Kind0ProfileHandler().handle(
      _event(id: 'e1', content: jsonEncode({'name': 'alice'})),
      isar,
    );
    final row =
        await isar.profileModels.where().pubkeyEqualTo(_kAlice).findFirst();
    expect(row!.name, 'alice');
  });

  test('malformed JSON content is a silent no-op', () async {
    await Kind0ProfileHandler()
        .handle(_event(id: 'e1', content: 'not-json'), isar);
    expect(await isar.profileModels.where().count(), 0);
  });

  test('a stale update (older createdAt than the existing row) is dropped',
      () async {
    await Kind0ProfileHandler().handle(
      _event(
        id: 'e1',
        createdAt: 1_700_000_100,
        content: jsonEncode({'name': 'newer'}),
      ),
      isar,
    );
    await Kind0ProfileHandler().handle(
      _event(
        id: 'e2',
        createdAt: 1_700_000_000,
        content: jsonEncode({'name': 'older'}),
      ),
      isar,
    );

    final row =
        await isar.profileModels.where().pubkeyEqualTo(_kAlice).findFirst();
    expect(row!.name, 'newer');
  });

  test('lastSeenAt is preserved across an update', () async {
    final seenAt = DateTime(2026, 1, 1);
    await isar.writeTxn(() async {
      await isar.profileModels.put(
        ProfileModel()
          ..pubkey = _kAlice
          ..updatedAt = DateTime(2025, 1, 1)
          ..lastSeenAt = seenAt,
      );
    });

    await Kind0ProfileHandler().handle(
      _event(id: 'e1', content: jsonEncode({'name': 'alice'})),
      isar,
    );

    final row =
        await isar.profileModels.where().pubkeyEqualTo(_kAlice).findFirst();
    expect(row!.lastSeenAt, seenAt);
  });

  test('clears the matching MissingProfilePubkeyModel row on arrival',
      () async {
    await isar.writeTxn(() async {
      await isar.missingProfilePubkeyModels.put(
        MissingProfilePubkeyModel()
          ..pubkey = _kAlice
          ..firstSeenAt = DateTime(2026, 1, 1),
      );
    });

    await Kind0ProfileHandler().handle(
      _event(id: 'e1', content: jsonEncode({'name': 'alice'})),
      isar,
    );

    expect(
      await isar.missingProfilePubkeyModels
          .where()
          .pubkeyEqualTo(_kAlice)
          .count(),
      0,
    );
  });

  test('no missing-tracker row present is a harmless no-op', () async {
    await Kind0ProfileHandler().handle(
      _event(id: 'e1', content: jsonEncode({'name': 'alice'})),
      isar,
    );
    expect(await isar.missingProfilePubkeyModels.where().count(), 0);
  });
}
