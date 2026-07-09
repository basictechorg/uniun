// Integration tests for [ManasSyncScope]. Real Isar, real MeshEventCodec.
// The `d` tag is the Manas's `manasId`, so create / rename / delete all
// address the same addressable slot per plan §5.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/features/mesh/sync/bodies/manas_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/manas_sync_scope.dart';

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
  late ManasSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    codec = MeshEventCodec(privkeyHex: me.private, pubkeyHex: me.public);
    scope = ManasSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  ManasModel makeRow(String id, {String name = 'Research'}) => ManasModel()
    ..manasId = id
    ..name = name
    ..description = 'notes I want to remember'
    ..iconName = 'science'
    ..createdAt = DateTime.fromMillisecondsSinceEpoch(1720000000000)
    ..updatedAt = DateTime.fromMillisecondsSinceEpoch(1720000000000);

  Future<String> seedSignedRow(
    String id, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
    String name = 'Research',
  }) async {
    final row = makeRow(id, name: name);
    final body = state == MeshRecordState.active
        ? ManasBody.forActive(row)
        : ManasBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: id,
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.manasModels.put(row));
    return signed;
  }

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedRow('m-a', createdAtSec: 1720000000);
    await isar.writeTxn(() => isar.manasModels.put(makeRow('m-b')));

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  test('signedEvent looks up a row by outer event id', () async {
    final signed = await seedSignedRow('m-a', createdAtSec: 1720000000);
    final id = (await codec.openRecord(signed)).event['id'] as String;
    final found = await scope.signedEvent(id);
    expect(found, signed);
  });

  test('signedEvent returns null for an unknown id', () async {
    await seedSignedRow('m-a', createdAtSec: 1720000000);
    expect(await scope.signedEvent('unknown'), isNull);
  });

  test('upsertSigned inserts a new active row keyed by manasId', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-new',
      content: ManasBody.forActive(makeRow('m-new', name: 'Fresh')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row =
        await isar.manasModels.where().manasIdEqualTo('m-new').findFirst();
    expect(row, isNotNull);
    expect(row!.name, 'Fresh');
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active row to tombstone on newer removed event',
      () async {
    await seedSignedRow('m-a', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-a',
      content: ManasBody.forRemoved(makeRow('m-a')),
      createdAtSec: 1720000100,
    );
    await scope.upsertSigned(tombstone);

    final row =
        await isar.manasModels.where().manasIdEqualTo('m-a').findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  test('upsertSigned drops an older event when local is newer', () async {
    await seedSignedRow('m-a', createdAtSec: 1720000200);
    final older = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-a',
      content: ManasBody.forActive(makeRow('m-a', name: 'Older')),
      createdAtSec: 1720000100,
    );

    await scope.upsertSigned(older);

    final row =
        await isar.manasModels.where().manasIdEqualTo('m-a').findFirst();
    expect(row!.name, 'Research');
  });

  test('upsertSigned survives out-of-order create → delete → rename', () async {
    final createOld = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-a',
      content: ManasBody.forActive(makeRow('m-a', name: 'v1')),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-a',
      content: ManasBody.forRemoved(makeRow('m-a', name: 'v1')),
      createdAtSec: 1720000200,
    );
    final renameNew = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-a',
      content: ManasBody.forActive(makeRow('m-a', name: 'v3')),
      createdAtSec: 1720000300,
    );

    await scope.upsertSigned(renameNew);
    await scope.upsertSigned(createOld);
    await scope.upsertSigned(removed);

    final row =
        await isar.manasModels.where().manasIdEqualTo('m-a').findFirst();
    expect(row!.removedAt, isNull);
    expect(row.name, 'v3');
    expect(row.signedNostrEvent, renameNew);
  });

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreign = Keychain.generate();
    final foreignCodec =
        MeshEventCodec(privkeyHex: foreign.private, pubkeyHex: foreign.public);
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-foreign',
      content: ManasBody.forActive(makeRow('m-foreign')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.manasModels.count(), 0);
  });

  test('upsertSigned silently drops a tampered event', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.manas,
      dTag: 'm-tamper',
      content: ManasBody.forActive(makeRow('m-tamper')),
      createdAtSec: 1720000000,
    );
    final tampered = signed.replaceFirstMapped(
      RegExp(r'"sig":"([0-9a-f])'),
      (m) => '"sig":"${_flipHex(m.group(1)!)}',
    );
    expect(tampered != signed, isTrue);

    await scope.upsertSigned(tampered);

    expect(await isar.manasModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-manas kind', () async {
    final wrongKind = await codec.signRecord(
      kind: 30599,
      dTag: 'm-x',
      content: ManasBody.forActive(makeRow('m-x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.manasModels.count(), 0);
  });
}

/// Deterministic hex tamper — nudges 0→1 (or f→0) so the tampered string is
/// guaranteed to differ from the original regardless of what char was there.
String _flipHex(String c) => c == '0' ? '1' : '0';
