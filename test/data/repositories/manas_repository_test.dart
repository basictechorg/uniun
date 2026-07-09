import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/data/repositories/manas_repository_impl.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

import '../../_helpers/isar_test_harness.dart';
import '../../_helpers/stub_user_repository.dart';

ManasEntity _manas({
  String id = 'm-1',
  String name = 'Goals',
  String? description,
  String? icon,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    ManasEntity(
      manasId: id,
      name: name,
      description: description,
      iconName: icon,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    );

/// Data-layer tests for [ManasRepositoryImpl]. Real on-disk Isar (no mocks)
/// via [openTestIsar]. Each test runs against a clean DB and tears it down.
///
/// Signer is wired against a logged-out stub — `sign()` returns null so
/// `signedNostrEvent` stays null. These tests assert on Isar row shape and
/// query semantics; the wire form is covered by mesh integration tests.
///
/// Verifies:
///   - upsertManas: insert / update-in-place by `manasId` (no duplicate row)
///   - getManasList: sortByUpdatedAt-DESC, with stitched noteCount per row,
///     tombstones hidden
///   - getManasById: hit / notFound failure (tombstoned rows count as
///     not-found — they are gone from the UI point of view)
///   - deleteManas: TOMBSTONES the Manas + every active link (mesh-idempotent
///     undo per plan §5a — rows survive so peer devices converge on "removed")
///   - addNoteToManas: idempotent (re-adding same pair is a no-op)
///   - removeNoteFromManas: tombstones the specific pair, leaves others
///   - getNoteIdsForManas: sortByAddedAt — preserves insertion order, hides
///     tombstoned links
///   - getManasIdsForNote: inverse query (1 note → many manases), hides
///     tombstoned links
void main() {
  late Isar isar;
  late ManasRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    final signer = MeshEventSigner(StubUserRepository()..keys = null);
    repo = ManasRepositoryImpl(isar: isar, signer: signer);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  // ── upsertManas ─────────────────────────────────────────────────────────

  group('upsertManas', () {
    test('inserts a new row and returns it with noteCount=0', () async {
      final r = await repo.upsertManas(_manas(id: 'a'));
      final saved = r.getOrElse(() => throw 'left');
      expect(saved.manasId, 'a');
      expect(saved.noteCount, 0);
      expect(await isar.manasModels.where().count(), 1);
    });

    test('updating an existing manas overwrites in place (no duplicate row)', () async {
      await repo.upsertManas(_manas(id: 'a', name: 'v1'));
      await repo.upsertManas(_manas(
        id: 'a',
        name: 'v2',
        updatedAt: DateTime(2026, 6, 1),
      ));
      final rows = await isar.manasModels.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'v2');
      expect(rows.single.updatedAt, DateTime(2026, 6, 1));
    });

    test('returned noteCount reflects current links', () async {
      await repo.upsertManas(_manas(id: 'a'));
      await repo.addNoteToManas('a', 'n-1');
      await repo.addNoteToManas('a', 'n-2');
      final r = await repo.upsertManas(_manas(id: 'a', name: 'updated'));
      expect(r.getOrElse(() => throw 'left').noteCount, 2);
    });
  });

  // ── getManasList ────────────────────────────────────────────────────────

  group('getManasList', () {
    test('returns rows sorted by updatedAt-DESC', () async {
      await repo.upsertManas(_manas(id: 'old', updatedAt: DateTime(2026, 1, 1)));
      await repo.upsertManas(_manas(id: 'new', updatedAt: DateTime(2026, 6, 1)));
      await repo.upsertManas(_manas(id: 'mid', updatedAt: DateTime(2026, 3, 1)));
      final list = (await repo.getManasList()).getOrElse(() => []);
      expect(list.map((m) => m.manasId), ['new', 'mid', 'old']);
    });

    test('each entry carries its real noteCount', () async {
      await repo.upsertManas(_manas(id: 'busy'));
      await repo.upsertManas(_manas(id: 'empty'));
      await repo.addNoteToManas('busy', 'n-1');
      await repo.addNoteToManas('busy', 'n-2');
      await repo.addNoteToManas('busy', 'n-3');

      final list = (await repo.getManasList()).getOrElse(() => []);
      final byId = {for (final m in list) m.manasId: m.noteCount};
      expect(byId, {'busy': 3, 'empty': 0});
    });

    test('empty repo → empty list', () async {
      expect((await repo.getManasList()).getOrElse(() => const []), isEmpty);
    });
  });

  // ── getManasById ────────────────────────────────────────────────────────

  group('getManasById', () {
    test('returns the manas with current noteCount', () async {
      await repo.upsertManas(_manas(id: 'a'));
      await repo.addNoteToManas('a', 'n-1');
      final r = await repo.getManasById('a');
      expect(r.getOrElse(() => throw 'left').noteCount, 1);
    });

    test('missing → notFoundFailure', () async {
      final r = await repo.getManasById('ghost');
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f.toString().toLowerCase(), contains('not found')),
        (_) => fail('expected Left'),
      );
    });
  });

  // ── deleteManas ─────────────────────────────────────────────────────────

  group('deleteManas', () {
    test(
        'tombstones the manas AND every active link belonging to it '
        '(mesh-idempotent undo per §5a)', () async {
      await repo.upsertManas(_manas(id: 'doomed'));
      await repo.upsertManas(_manas(id: 'survivor'));
      await repo.addNoteToManas('doomed', 'n-1');
      await repo.addNoteToManas('doomed', 'n-2');
      await repo.addNoteToManas('survivor', 'n-1');

      await repo.deleteManas('doomed');

      // Rows survive (both Manas and links) as tombstones so peer devices
      // converge on "removed" via negentropy.
      expect(await isar.manasModels.where().count(), 2,
          reason: 'raw row count includes the tombstoned Manas');
      expect(await isar.manasNoteLinkModels.where().count(), 3,
          reason: 'raw link count includes tombstoned links');

      // Repo-level query hides tombstones from the UI.
      final visible = (await repo.getManasList()).getOrElse(() => const []);
      expect(visible.map((m) => m.manasId).toList(), ['survivor']);

      final survivor =
          (await repo.getManasById('survivor')).getOrElse(() => throw 'left');
      expect(survivor.noteCount, 1);

      // Doomed Manas is no longer resolvable via the repo (notFound).
      expect((await repo.getManasById('doomed')).isLeft(), isTrue);
    });

    test('deleting a missing manas is a silent no-op (Right(unit))', () async {
      final r = await repo.deleteManas('ghost');
      expect(r.isRight(), isTrue);
    });
  });

  // ── addNoteToManas ──────────────────────────────────────────────────────

  group('addNoteToManas', () {
    test('inserts a link row', () async {
      await repo.addNoteToManas('m', 'n');
      expect(await isar.manasNoteLinkModels.where().count(), 1);
    });

    test('re-adding the same (manasId, noteId) is idempotent — single row', () async {
      await repo.addNoteToManas('m', 'n');
      await repo.addNoteToManas('m', 'n');
      await repo.addNoteToManas('m', 'n');
      expect(await isar.manasNoteLinkModels.where().count(), 1);
    });
  });

  // ── removeNoteFromManas ─────────────────────────────────────────────────

  group('removeNoteFromManas', () {
    test('tombstones only the targeted pair, leaves the others active',
        () async {
      await repo.addNoteToManas('m1', 'n');
      await repo.addNoteToManas('m2', 'n');
      await repo.addNoteToManas('m1', 'other');

      await repo.removeNoteFromManas('m1', 'n');

      // Raw table still holds all three rows (tombstone survives).
      expect(await isar.manasNoteLinkModels.where().count(), 3);

      // Repo queries filter out the tombstoned row.
      expect(
        (await repo.getNoteIdsForManas('m1')).getOrElse(() => const <String>[]),
        ['other'],
      );
      expect(
        (await repo.getManasIdsForNote('n')).getOrElse(() => const <String>[]),
        ['m2'],
      );
    });

    test('removing a non-existent pair is a no-op', () async {
      final r = await repo.removeNoteFromManas('ghost', 'nope');
      expect(r.isRight(), isTrue);
    });
  });

  // ── getNoteIdsForManas / getManasIdsForNote ─────────────────────────────

  group('link queries', () {
    test('getNoteIdsForManas returns ids in addedAt order', () async {
      await repo.addNoteToManas('m', 'first');
      // Wait long enough to clear DateTime.now() resolution.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.addNoteToManas('m', 'second');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.addNoteToManas('m', 'third');

      final ids = (await repo.getNoteIdsForManas('m')).getOrElse(() => []);
      expect(ids, ['first', 'second', 'third']);
    });

    test('getManasIdsForNote returns every manas containing the note', () async {
      await repo.addNoteToManas('work', 'n');
      await repo.addNoteToManas('personal', 'n');
      await repo.addNoteToManas('work', 'unrelated');

      final ids = (await repo.getManasIdsForNote('n')).getOrElse(() => []);
      expect(ids.toSet(), {'work', 'personal'});
    });

    test('queries on unknown ids return empty lists, not errors', () async {
      expect(
        (await repo.getNoteIdsForManas('ghost')).getOrElse(() => const <String>[]),
        isEmpty,
      );
      expect(
        (await repo.getManasIdsForNote('ghost')).getOrElse(() => const <String>[]),
        isEmpty,
      );
    });
  });
}
