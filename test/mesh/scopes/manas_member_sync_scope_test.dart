// Integration tests for [ManasMemberSyncScope]. Real Isar, real MeshEventCodec.
// The `d` tag encodes `(manasId, noteId)` via [ManasMemberBody.buildDTag], so
// add / remove for one pair address the same addressable slot per plan §5.

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/features/mesh/sync/bodies/manas_member_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/manas_member_sync_scope.dart';

import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/mesh_test_helpers.dart';

void main() {
  stubSecureStorageChannel();

  late Isar isar;
  late MeshIdentity me;
  late MeshEventCodec codec;
  late ManasMemberSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = MeshIdentity.generate();
    codec = me.codec;
    scope = ManasMemberSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  ManasNoteLinkModel makeLink(String manasId, String noteId) =>
      ManasNoteLinkModel()
        ..manasId = manasId
        ..noteId = noteId
        ..addedAt = DateTime.fromMillisecondsSinceEpoch(1720000000000);

  Future<String> seedSignedLink(
    String manasId,
    String noteId, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
  }) async {
    final row = makeLink(manasId, noteId);
    final body = state == MeshRecordState.active
        ? ManasMemberBody.forActive(row)
        : ManasMemberBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag(manasId, noteId),
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.manasNoteLinkModels.put(row));
    return signed;
  }

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedLink('m', 'n1', createdAtSec: 1720000000);
    await isar.writeTxn(
      () => isar.manasNoteLinkModels.put(makeLink('m', 'n2')),
    );

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  test('signedEvent looks up a link by outer event id', () async {
    final signed = await seedSignedLink('m', 'n1', createdAtSec: 1720000000);
    final id = (await codec.openRecord(signed)).event['id'] as String;
    final found = await scope.signedEvent(id);
    expect(found, signed);
  });

  test('upsertSigned inserts a new active link keyed by (manasId, noteId)',
      () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag('m', 'n-new'),
      content: ManasMemberBody.forActive(makeLink('m', 'n-new')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row = await isar.manasNoteLinkModels
        .filter()
        .manasIdEqualTo('m')
        .noteIdEqualTo('n-new')
        .findFirst();
    expect(row, isNotNull);
    expect(row!.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active link to tombstone on newer removed event',
      () async {
    await seedSignedLink('m', 'n', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag('m', 'n'),
      content: ManasMemberBody.forRemoved(makeLink('m', 'n')),
      createdAtSec: 1720000100,
    );
    await scope.upsertSigned(tombstone);

    final row = await isar.manasNoteLinkModels
        .filter()
        .manasIdEqualTo('m')
        .noteIdEqualTo('n')
        .findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  test('upsertSigned survives out-of-order add → remove → add', () async {
    final addOld = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag('m', 'n'),
      content: ManasMemberBody.forActive(makeLink('m', 'n')),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag('m', 'n'),
      content: ManasMemberBody.forRemoved(makeLink('m', 'n')),
      createdAtSec: 1720000200,
    );
    final addNew = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag('m', 'n'),
      content: ManasMemberBody.forActive(makeLink('m', 'n')),
      createdAtSec: 1720000300,
    );

    await scope.upsertSigned(addNew);
    await scope.upsertSigned(addOld);
    await scope.upsertSigned(removed);

    final row = await isar.manasNoteLinkModels
        .filter()
        .manasIdEqualTo('m')
        .noteIdEqualTo('n')
        .findFirst();
    expect(row!.removedAt, isNull);
    expect(row.signedNostrEvent, addNew);
  });

  test('upsertSigned silently drops an event with a malformed d tag',
      () async {
    // Sign an event with a d tag that has no colon → parseDTag returns null.
    final malformed = await codec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: 'no-colon-here',
      content: ManasMemberBody.forActive(makeLink('m', 'n')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(malformed);

    expect(await isar.manasNoteLinkModels.count(), 0);
  });

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreignCodec = MeshIdentity.generate().codec;
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.manasMember,
      dTag: ManasMemberBody.buildDTag('m', 'n'),
      content: ManasMemberBody.forActive(makeLink('m', 'n')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.manasNoteLinkModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-manasMember kind',
      () async {
    final wrongKind = await codec.signRecord(
      kind: 30599,
      dTag: ManasMemberBody.buildDTag('m', 'n'),
      content: ManasMemberBody.forActive(makeLink('m', 'n')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.manasNoteLinkModels.count(), 0);
  });
}
