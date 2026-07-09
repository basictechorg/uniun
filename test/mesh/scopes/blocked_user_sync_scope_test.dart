// Integration tests for [BlockedUserSyncScope]. Real Isar, real MeshEventCodec.
// The `d` tag is the blocked user's `pubkeyHex` (not an event id), so
// block/unblock both address the same addressable slot per plan §5.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/features/mesh/sync/bodies/blocked_user_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/blocked_user_sync_scope.dart';

import '../../_helpers/isar_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const flutterSecureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(flutterSecureStorage, (_) async => null);

  late Isar isar;
  late Keychain me;
  late MeshEventCodec codec;
  late BlockedUserSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    codec = MeshEventCodec(privkeyHex: me.private, pubkeyHex: me.public);
    scope = BlockedUserSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  BlockedUserModel makeRow(String pk) => BlockedUserModel()
    ..pubkeyHex = pk
    ..blockedAt = DateTime.fromMillisecondsSinceEpoch(1720000100000);

  Future<String> seedSignedRow(
    String pk, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
  }) async {
    final row = makeRow(pk);
    final body = state == MeshRecordState.active
        ? BlockedUserBody.forActive(row)
        : BlockedUserBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: pk,
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.blockedUserModels.put(row));
    return signed;
  }

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedRow('pk-a', createdAtSec: 1720000000);
    await isar.writeTxn(() => isar.blockedUserModels.put(makeRow('pk-b')));

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  test('signedEvent looks up a row by outer event id', () async {
    final signed = await seedSignedRow('pk-a', createdAtSec: 1720000000);
    final id = (await codec.openRecord(signed)).event['id'] as String;
    final found = await scope.signedEvent(id);
    expect(found, signed);
  });

  test('signedEvent returns null for an unknown id', () async {
    await seedSignedRow('pk-a', createdAtSec: 1720000000);
    expect(await scope.signedEvent('unknown'), isNull);
  });

  test('upsertSigned inserts a new active row keyed by pubkey', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-new',
      content: BlockedUserBody.forActive(makeRow('pk-new')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row = await isar.blockedUserModels
        .where()
        .pubkeyHexEqualTo('pk-new')
        .findFirst();
    expect(row, isNotNull);
    expect(row!.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active row to tombstone on newer removed event',
      () async {
    await seedSignedRow('pk-a', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-a',
      content: BlockedUserBody.forRemoved(makeRow('pk-a')),
      createdAtSec: 1720000100,
    );
    await scope.upsertSigned(tombstone);

    final row = await isar.blockedUserModels
        .where()
        .pubkeyHexEqualTo('pk-a')
        .findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  test('upsertSigned drops an older event when local is newer', () async {
    await seedSignedRow('pk-a', createdAtSec: 1720000200);
    final older = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-a',
      content: BlockedUserBody.forActive(makeRow('pk-a')),
      createdAtSec: 1720000100,
    );

    final localBefore = (await isar.blockedUserModels
            .where()
            .pubkeyHexEqualTo('pk-a')
            .findFirst())!
        .signedNostrEvent;
    await scope.upsertSigned(older);
    final localAfter = (await isar.blockedUserModels
            .where()
            .pubkeyHexEqualTo('pk-a')
            .findFirst())!
        .signedNostrEvent;
    expect(localAfter, localBefore);
  });

  test('upsertSigned survives out-of-order block→unblock→block', () async {
    final activeOld = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-a',
      content: BlockedUserBody.forActive(makeRow('pk-a')),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-a',
      content: BlockedUserBody.forRemoved(makeRow('pk-a')),
      createdAtSec: 1720000200,
    );
    final activeNew = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-a',
      content: BlockedUserBody.forActive(makeRow('pk-a')),
      createdAtSec: 1720000300,
    );

    await scope.upsertSigned(activeNew);
    await scope.upsertSigned(activeOld);
    await scope.upsertSigned(removed);

    final row = await isar.blockedUserModels
        .where()
        .pubkeyHexEqualTo('pk-a')
        .findFirst();
    expect(row!.removedAt, isNull);
    expect(row.signedNostrEvent, activeNew);
  });

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreign = Keychain.generate();
    final foreignCodec =
        MeshEventCodec(privkeyHex: foreign.private, pubkeyHex: foreign.public);
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-foreign',
      content: BlockedUserBody.forActive(makeRow('pk-foreign')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.blockedUserModels.count(), 0);
  });

  test('upsertSigned silently drops a tampered event', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.blockedUser,
      dTag: 'pk-tamper',
      content: BlockedUserBody.forActive(makeRow('pk-tamper')),
      createdAtSec: 1720000000,
    );
    final tampered = signed.replaceFirstMapped(
      RegExp(r'"sig":"([0-9a-f])'),
      (m) => '"sig":"${_flipHex(m.group(1)!)}',
    );
    expect(tampered != signed, isTrue);

    await scope.upsertSigned(tampered);

    expect(await isar.blockedUserModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-blockedUser kind',
      () async {
    final wrongKind = await codec.signRecord(
      kind: 30599,
      dTag: 'pk-x',
      content: BlockedUserBody.forActive(makeRow('pk-x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.blockedUserModels.count(), 0);
  });
}

/// Deterministic hex tamper — nudges 0→1 (or f→0) so the tampered string is
/// guaranteed to differ from the original regardless of what char was there.
String _flipHex(String c) => c == '0' ? '1' : '0';
