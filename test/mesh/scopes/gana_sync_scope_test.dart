// Integration tests for [GanaSyncScope]. Real Isar, real MeshEventCodec.
// The `d` tag is the Gana's `ganaId`, so create / rename / enable-toggle /
// delete all address the same addressable slot per plan §5.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/features/mesh/sync/bodies/gana_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/gana_sync_scope.dart';

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
  late GanaSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    codec = MeshEventCodec(privkeyHex: me.private, pubkeyHex: me.public);
    scope = GanaSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  GanaModel makeRow(String id, {String name = 'Daily digest'}) => GanaModel()
    ..ganaId = id
    ..name = name
    ..manasIds = const ['manas-a']
    ..taskPrompt = 'do the thing'
    ..outputType = GanaOutputType.feed
    ..triggerReactive = false
    ..triggerIntervalMinutes = 60
    ..triggerMode = GanaTriggerMode.recurring
    ..maxOutputs = 5
    ..enabled = true
    ..createdAt = DateTime.fromMillisecondsSinceEpoch(1720000000000)
    ..updatedAt = DateTime.fromMillisecondsSinceEpoch(1720000000000);

  Future<String> seedSignedRow(
    String id, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
    String name = 'Daily digest',
  }) async {
    final row = makeRow(id, name: name);
    final body = state == MeshRecordState.active
        ? GanaBody.forActive(row)
        : GanaBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: id,
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.ganaModels.put(row));
    return signed;
  }

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedRow('g-a', createdAtSec: 1720000000);
    await isar.writeTxn(() => isar.ganaModels.put(makeRow('g-b')));

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  test('signedEvent looks up a Gana by outer event id', () async {
    final signed = await seedSignedRow('g-a', createdAtSec: 1720000000);
    final id = (await codec.openRecord(signed)).event['id'] as String;
    final found = await scope.signedEvent(id);
    expect(found, signed);
  });

  test('signedEvent returns null for an unknown id', () async {
    await seedSignedRow('g-a', createdAtSec: 1720000000);
    expect(await scope.signedEvent('unknown'), isNull);
  });

  test('upsertSigned inserts a new active Gana keyed by ganaId', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-new',
      content: GanaBody.forActive(makeRow('g-new', name: 'Fresh')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row =
        await isar.ganaModels.where().ganaIdEqualTo('g-new').findFirst();
    expect(row, isNotNull);
    expect(row!.name, 'Fresh');
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active Gana to tombstone on newer removed event',
      () async {
    await seedSignedRow('g-a', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-a',
      content: GanaBody.forRemoved(makeRow('g-a')),
      createdAtSec: 1720000100,
    );
    await scope.upsertSigned(tombstone);

    final row =
        await isar.ganaModels.where().ganaIdEqualTo('g-a').findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  test('upsertSigned drops an older event when local is newer', () async {
    await seedSignedRow('g-a', createdAtSec: 1720000200, name: 'Current');
    final older = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-a',
      content: GanaBody.forActive(makeRow('g-a', name: 'Older')),
      createdAtSec: 1720000100,
    );

    await scope.upsertSigned(older);

    final row =
        await isar.ganaModels.where().ganaIdEqualTo('g-a').findFirst();
    expect(row!.name, 'Current');
  });

  test('upsertSigned survives out-of-order enable → disable → rename',
      () async {
    final createOld = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-a',
      content: GanaBody.forActive(makeRow('g-a', name: 'v1')),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-a',
      content: GanaBody.forRemoved(makeRow('g-a', name: 'v1')),
      createdAtSec: 1720000200,
    );
    final renameNew = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-a',
      content: GanaBody.forActive(makeRow('g-a', name: 'v3')),
      createdAtSec: 1720000300,
    );

    await scope.upsertSigned(renameNew);
    await scope.upsertSigned(createOld);
    await scope.upsertSigned(removed);

    final row =
        await isar.ganaModels.where().ganaIdEqualTo('g-a').findFirst();
    expect(row!.removedAt, isNull);
    expect(row.name, 'v3');
    expect(row.signedNostrEvent, renameNew);
  });

  test('upsertSigned preserves per-device cursor state on remote apply',
      () async {
    // Local Gana has runtime cursor set. Remote sends a definition update.
    // The cursor must survive.
    final row = makeRow('g-cursor', name: 'orig');
    row
      ..lastProcessedEventId = 'local-abc'
      ..lastProcessedCreated = DateTime.fromMillisecondsSinceEpoch(1720000050000)
      ..lastRunAt = DateTime.fromMillisecondsSinceEpoch(1720000050000);
    row.signedNostrEvent = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-cursor',
      content: GanaBody.forActive(row),
      createdAtSec: 1720000000,
    );
    await isar.writeTxn(() => isar.ganaModels.put(row));

    final renamed = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-cursor',
      content: GanaBody.forActive(makeRow('g-cursor', name: 'renamed')),
      createdAtSec: 1720000200,
    );
    await scope.upsertSigned(renamed);

    final after = await isar.ganaModels
        .where()
        .ganaIdEqualTo('g-cursor')
        .findFirst();
    expect(after!.name, 'renamed');
    expect(after.lastProcessedEventId, 'local-abc');
    expect(after.lastProcessedCreated!.millisecondsSinceEpoch, 1720000050000);
    expect(after.lastRunAt!.millisecondsSinceEpoch, 1720000050000);
  });

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreign = Keychain.generate();
    final foreignCodec =
        MeshEventCodec(privkeyHex: foreign.private, pubkeyHex: foreign.public);
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-foreign',
      content: GanaBody.forActive(makeRow('g-foreign')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.ganaModels.count(), 0);
  });

  test('upsertSigned silently drops a tampered event', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.gana,
      dTag: 'g-tamper',
      content: GanaBody.forActive(makeRow('g-tamper')),
      createdAtSec: 1720000000,
    );
    final tampered = signed.replaceFirstMapped(
      RegExp(r'"sig":"([0-9a-f])'),
      (m) => '"sig":"${_flipHex(m.group(1)!)}',
    );
    expect(tampered != signed, isTrue);

    await scope.upsertSigned(tampered);

    expect(await isar.ganaModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-gana kind', () async {
    final wrongKind = await codec.signRecord(
      kind: 30599,
      dTag: 'g-x',
      content: GanaBody.forActive(makeRow('g-x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.ganaModels.count(), 0);
  });
}

/// Deterministic hex tamper — nudges 0→1 (or f→0) so the tampered string is
/// guaranteed to differ from the original regardless of what char was there.
String _flipHex(String c) => c == '0' ? '1' : '0';
