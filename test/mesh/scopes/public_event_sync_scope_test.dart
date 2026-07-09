// Covers: Kind-0 profile raw-event indexing, lookup, handler dispatch, and drops.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/features/mesh/sync/scopes/public_event_sync_scope.dart';

import '../../_helpers/isar_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Keychain me;
  late Keychain other;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    other = Keychain.generate();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  String signKind0(
    Keychain keychain, {
    required int createdAtSec,
    String name = 'Alice',
    String about = 'hi',
  }) {
    final event = Event.from(
      kind: 0,
      tags: const [],
      content: jsonEncode({'name': name, 'about': about}),
      privkey: keychain.private,
      createdAt: createdAtSec,
    );
    return jsonEncode(event.toJson());
  }

  Future<void> seedProfileRaw(String signedJson) async {
    final raw = jsonDecode(signedJson) as Map<String, dynamic>;
    final event = Event.fromJson(raw, verify: false);
    await isar.writeTxn(() async {
      await isar.profileModels.put(
        ProfileModel()
          ..pubkey = event.pubkey
          ..name = 'seeded'
          ..updatedAt = DateTime.fromMillisecondsSinceEpoch(
            event.createdAt * 1000,
          )
          ..rawEventJson = signedJson,
      );
    });
  }

  PublicEventSyncScope scopeFor(Keychain active) =>
      PublicEventSyncScope(isar, activePubkeyHex: active.public);

  test(
    'localIndex returns event ids and created_at for stored profile events',
    () async {
      await seedProfileRaw(signKind0(me, createdAtSec: 1720000000));
      await seedProfileRaw(signKind0(other, createdAtSec: 1720000200));

      final index = await scopeFor(me).localIndex();

      expect(index.length, 2);
      expect(index.values.toSet(), {1720000000, 1720000200});
    },
  );

  test('signedEvent looks up profile raw JSON by event id', () async {
    final signed = signKind0(me, createdAtSec: 1720000000);
    await seedProfileRaw(signed);
    final id = (jsonDecode(signed) as Map<String, dynamic>)['id'] as String;

    final found = await scopeFor(me).signedEvent(id);

    expect(found, isNotNull);
    final foundId =
        (jsonDecode(found!) as Map<String, dynamic>)['id'] as String;
    expect(foundId, id);
  });

  test('signedEvent returns null for an unknown id', () async {
    expect(await scopeFor(me).signedEvent('unknown'), isNull);
  });

  test('upsertSigned applies a Kind-0 event authored by anyone', () async {
    final signed = signKind0(other, createdAtSec: 1720000000, name: 'Bob');

    await scopeFor(me).upsertSigned(signed);

    final row = await isar.profileModels
        .where()
        .pubkeyEqualTo(other.public)
        .findFirst();
    expect(row, isNotNull);
    expect(row!.name, 'Bob');
    expect(row.rawEventJson, isNotNull);
  });

  test('upsertSigned silently drops an event of an unsupported kind', () async {
    final event = Event.from(
      kind: 1,
      tags: const [],
      content: 'hello',
      privkey: me.private,
      createdAt: 1720000000,
    );

    await scopeFor(me).upsertSigned(jsonEncode(event.toJson()));

    expect(await isar.profileModels.count(), 0);
  });

  test(
    'upsertSigned silently drops an event with a tampered signature',
    () async {
      final signed = signKind0(me, createdAtSec: 1720000000);
      final tampered = signed.replaceFirstMapped(
        RegExp(r'"sig":"([0-9a-f])'),
        (match) => '"sig":"${match.group(1)! == '0' ? '1' : '0'}',
      );
      expect(tampered != signed, isTrue);

      await scopeFor(me).upsertSigned(tampered);

      expect(await isar.profileModels.count(), 0);
    },
  );

  test('upsertSigned silently drops non-JSON garbage', () async {
    await scopeFor(me).upsertSigned('this is not JSON at all');
    await scopeFor(me).upsertSigned('123');

    expect(await isar.profileModels.count(), 0);
  });

  test(
    'upsertSigned drops an older Kind-0 event when local has a newer one',
    () async {
      await scopeFor(
        me,
      ).upsertSigned(signKind0(me, createdAtSec: 1720000200, name: 'Alice v2'));
      await scopeFor(
        me,
      ).upsertSigned(signKind0(me, createdAtSec: 1720000100, name: 'Alice v1'));

      final profile = await isar.profileModels
          .where()
          .pubkeyEqualTo(me.public)
          .findFirst();
      expect(profile!.name, 'Alice v2');
      final raw = jsonDecode(profile.rawEventJson!) as Map<String, dynamic>;
      expect(raw['created_at'], 1720000200);
    },
  );
}
