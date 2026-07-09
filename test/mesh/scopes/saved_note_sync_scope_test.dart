// Integration tests for [SavedNoteSyncScope]. Real Isar, real MeshEventCodec.
// Verifies the negentropy contract: localIndex reflects what's on disk,
// signedEvent finds by id, upsertSigned applies LWW + tombstone semantics
// per plan §5a.

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/features/mesh/sync/bodies/saved_note_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/saved_note_sync_scope.dart';

import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/mesh_test_helpers.dart';

void main() {
  stubSecureStorageChannel();

  late Isar isar;
  late MeshIdentity me;
  late MeshEventCodec codec;
  late SavedNoteSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = MeshIdentity.generate();
    codec = me.codec;
    scope = SavedNoteSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  SavedNoteModel makeRow(String eventId, {String content = 'c'}) =>
      savedNoteRow(eventId, content: content, authorPubkey: me.pubkey);

  Future<String> seedSignedRow(
    String eventId, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
    String content = 'c',
  }) async {
    final row = makeRow(eventId, content: content);
    final body = state == MeshRecordState.active
        ? SavedNoteBody.forActive(row)
        : SavedNoteBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: eventId,
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.savedNoteModels.put(row));
    return signed;
  }

  // ── localIndex ──────────────────────────────────────────────────────────

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedRow('ev-a', createdAtSec: 1720000000);
    // Unsigned row — should be skipped.
    await isar.writeTxn(() => isar.savedNoteModels.put(makeRow('ev-b')));

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  // ── signedEvent ─────────────────────────────────────────────────────────

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

  // ── upsertSigned: happy path ────────────────────────────────────────────

  test('upsertSigned inserts a new active row', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-new',
      content: SavedNoteBody.forActive(makeRow('ev-new', content: 'incoming')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row = await isar.savedNoteModels
        .where()
        .eventIdEqualTo('ev-new')
        .findFirst();
    expect(row, isNotNull);
    expect(row!.content, 'incoming');
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active row to tombstone on newer removed event',
      () async {
    await seedSignedRow('ev-a', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-a',
      content: SavedNoteBody.forRemoved(makeRow('ev-a')),
      createdAtSec: 1720000100, // newer
    );
    await scope.upsertSigned(tombstone);

    final row = await isar.savedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  // ── upsertSigned: LWW ordering ─────────────────────────────────────────

  test('upsertSigned drops an older event when local is newer', () async {
    // Local is newer (createdAt 200); incoming is older (createdAt 100).
    await seedSignedRow('ev-a',
        createdAtSec: 1720000200, content: 'local-wins');
    final older = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-a',
      content: SavedNoteBody.forActive(makeRow('ev-a', content: 'stale-incoming')),
      createdAtSec: 1720000100,
    );

    await scope.upsertSigned(older);

    final row = await isar.savedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.content, 'local-wins');
  });

  test('upsertSigned tie-break: equal createdAt keeps the higher event id',
      () async {
    // Plan §5a: at identical created_at, the lexicographically-higher
    // event id wins deterministically — both peers converge on one row no
    // matter the apply order.
    final localSigned =
        await seedSignedRow('ev-a', createdAtSec: 1720000100, content: 'L');
    final incoming = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-a',
      content: SavedNoteBody.forActive(makeRow('ev-a', content: 'I')),
      createdAtSec: 1720000100, // same second
    );
    final localId = (await codec.openRecord(localSigned)).event['id'] as String;
    final incomingId = (await codec.openRecord(incoming)).event['id'] as String;

    await scope.upsertSigned(incoming);

    final row = await isar.savedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.content, localId.compareTo(incomingId) >= 0 ? 'L' : 'I');
  });

  test('upsertSigned survives an out-of-order save→unsave→save sequence', () async {
    // Plan §5a: applying two events out of order still converges to the
    // terminal state at the highest `created_at`.
    final activeOld = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-a',
      content: SavedNoteBody.forActive(makeRow('ev-a', content: 'v1')),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-a',
      content: SavedNoteBody.forRemoved(makeRow('ev-a', content: 'v1')),
      createdAtSec: 1720000200,
    );
    final activeNew = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-a',
      content: SavedNoteBody.forActive(makeRow('ev-a', content: 'v3')),
      createdAtSec: 1720000300,
    );

    // Apply in reverse order: newest first, then oldest, then middle. The
    // final row must reflect the newest event (state=active, content=v3).
    await scope.upsertSigned(activeNew);
    await scope.upsertSigned(activeOld);
    await scope.upsertSigned(removed);

    final row = await isar.savedNoteModels
        .where()
        .eventIdEqualTo('ev-a')
        .findFirst();
    expect(row!.content, 'v3');
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, activeNew);
  });

  // ── upsertSigned: security drops ───────────────────────────────────────

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreignCodec = MeshIdentity.generate().codec;
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-foreign',
      content: SavedNoteBody.forActive(makeRow('ev-foreign')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.savedNoteModels.count(), 0);
  });

  test('upsertSigned silently drops a tampered event', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'ev-tamper',
      content: SavedNoteBody.forActive(makeRow('ev-tamper', content: 'orig')),
      createdAtSec: 1720000000,
    );
    // Byte-flip a sig hex character in-place — id/sig mismatch, codec rejects.
    // Use replaceFirstMapped so the tamper is deterministically different
    // even when the first sig byte happens to already be the target char.
    final tampered = signed.replaceFirstMapped(
      RegExp(r'"sig":"([0-9a-f])'),
      (m) => '"sig":"${_flipHex(m.group(1)!)}',
    );
    expect(tampered != signed, isTrue);

    await scope.upsertSigned(tampered);

    expect(await isar.savedNoteModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-savedNote kind',
      () async {
    // A well-signed event but for a different addressable kind — the scope
    // must refuse it even though verify would pass.
    final wrongKind = await codec.signRecord(
      kind: 30599, // reserved-but-unused custom range
      dTag: 'ev-x',
      content: SavedNoteBody.forActive(makeRow('ev-x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.savedNoteModels.count(), 0);
  });
}

/// Deterministic hex tamper — nudges 0→1 (or f→0) so the tampered string is
/// guaranteed to differ from the original regardless of what char was there.
String _flipHex(String c) => c == '0' ? '1' : '0';
