// Integration tests for [FollowedNoteSyncScope]. Real Isar, real MeshEventCodec.
// Mirrors the negentropy contract enforced in saved_note_sync_scope_test.dart:
// localIndex reflects only signed rows, signedEvent looks up by outer event
// id, upsertSigned applies LWW + tombstone semantics per plan §5a.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/features/mesh/sync/bodies/followed_note_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/followed_note_sync_scope.dart';

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
  late FollowedNoteSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    codec = MeshEventCodec(privkeyHex: me.private, pubkeyHex: me.public);
    scope = FollowedNoteSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  FollowedNoteModel makeRow(String eventId, {String preview = 'p'}) =>
      FollowedNoteModel()
        ..eventId = eventId
        ..contentPreview = preview
        ..followedAt = DateTime.fromMillisecondsSinceEpoch(1720000100000);

  Future<String> seedSignedRow(
    String eventId, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
    String preview = 'p',
  }) async {
    final row = makeRow(eventId, preview: preview);
    final body = state == MeshRecordState.active
        ? FollowedNoteBody.forActive(row)
        : FollowedNoteBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: eventId,
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.followedNoteModels.put(row));
    return signed;
  }

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedRow('ev-a', createdAtSec: 1720000000);
    await isar.writeTxn(() => isar.followedNoteModels.put(makeRow('ev-b')));

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  test('signedEvent looks up a row by outer event id', () async {
    final signed = await seedSignedRow('ev-a', createdAtSec: 1720000000);
    final id = (await codec.openRecord(signed)).event['id'] as String;
    final found = await scope.signedEvent(id);
    expect(found, signed);
  });

  test('signedEvent returns null for an unknown id', () async {
    await seedSignedRow('ev-a', createdAtSec: 1720000000);
    expect(await scope.signedEvent('unknown'), isNull);
  });

  test('upsertSigned inserts a new active row', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-new',
      content: FollowedNoteBody.forActive(makeRow('ev-new', preview: 'x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row = await isar.followedNoteModels
        .where()
        .eventIdEqualTo('ev-new')
        .findFirst();
    expect(row, isNotNull);
    expect(row!.contentPreview, 'x');
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active row to tombstone on newer removed event',
      () async {
    await seedSignedRow('ev-a', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-a',
      content: FollowedNoteBody.forRemoved(makeRow('ev-a')),
      createdAtSec: 1720000100,
    );
    await scope.upsertSigned(tombstone);

    final row = await isar.followedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  test('upsertSigned drops an older event when local is newer', () async {
    await seedSignedRow('ev-a',
        createdAtSec: 1720000200, preview: 'local-wins');
    final older = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-a',
      content:
          FollowedNoteBody.forActive(makeRow('ev-a', preview: 'stale')),
      createdAtSec: 1720000100,
    );

    await scope.upsertSigned(older);

    final row = await isar.followedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.contentPreview, 'local-wins');
  });

  test('upsertSigned survives out-of-order follow→unfollow→follow', () async {
    final activeOld = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-a',
      content: FollowedNoteBody.forActive(makeRow('ev-a', preview: 'v1')),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-a',
      content: FollowedNoteBody.forRemoved(makeRow('ev-a')),
      createdAtSec: 1720000200,
    );
    final activeNew = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-a',
      content: FollowedNoteBody.forActive(makeRow('ev-a', preview: 'v3')),
      createdAtSec: 1720000300,
    );

    await scope.upsertSigned(activeNew);
    await scope.upsertSigned(activeOld);
    await scope.upsertSigned(removed);

    final row = await isar.followedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.contentPreview, 'v3');
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, activeNew);
  });

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreign = Keychain.generate();
    final foreignCodec =
        MeshEventCodec(privkeyHex: foreign.private, pubkeyHex: foreign.public);
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-foreign',
      content: FollowedNoteBody.forActive(makeRow('ev-foreign')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.followedNoteModels.count(), 0);
  });

  test('upsertSigned silently drops a tampered event', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.followedNote,
      dTag: 'ev-tamper',
      content: FollowedNoteBody.forActive(makeRow('ev-tamper')),
      createdAtSec: 1720000000,
    );
    final tampered = signed.replaceFirstMapped(
      RegExp(r'"sig":"([0-9a-f])'),
      (m) => '"sig":"${_flipHex(m.group(1)!)}',
    );
    expect(tampered != signed, isTrue);

    await scope.upsertSigned(tampered);

    expect(await isar.followedNoteModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-followedNote kind',
      () async {
    final wrongKind = await codec.signRecord(
      kind: 30599,
      dTag: 'ev-x',
      content: FollowedNoteBody.forActive(makeRow('ev-x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.followedNoteModels.count(), 0);
  });
}

/// Deterministic hex tamper — nudges 0→1 (or f→0) so the tampered string is
/// guaranteed to differ from the original regardless of what char was there.
String _flipHex(String c) => c == '0' ? '1' : '0';
