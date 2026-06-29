import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/data/repositories/manas_repository_impl.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';

import '../../_helpers/isar_test_harness.dart';

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
/// Verifies:
///   - upsertManas: insert / update-in-place by `manasId` (no duplicate row)
///   - getManasList: sortByUpdatedAt-DESC, with stitched noteCount per row
///   - getManasById: hit / notFound failure
///   - deleteManas: cascades the linked note rows
///   - addNoteToManas: idempotent (re-adding same pair is a no-op)
///   - removeNoteFromManas: removes only the (manasId, noteId) pair
///   - getNoteIdsForManas: sortByAddedAt — preserves insertion order
///   - getManasIdsForNote: inverse query (1 note → many manases)
void main() {
  late Isar isar;
  late ManasRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    repo = ManasRepositoryImpl(isar: isar);
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
    test('removes the manas AND every link belonging to it', () async {
      await repo.upsertManas(_manas(id: 'doomed'));
      await repo.upsertManas(_manas(id: 'survivor'));
      await repo.addNoteToManas('doomed', 'n-1');
      await repo.addNoteToManas('doomed', 'n-2');
      await repo.addNoteToManas('survivor', 'n-1');

      await repo.deleteManas('doomed');

      expect(await isar.manasModels.where().count(), 1);
      expect(await isar.manasNoteLinkModels.where().count(), 1,
          reason: 'only the survivor\'s 1 link should remain');
      final survivor =
          (await repo.getManasById('survivor')).getOrElse(() => throw 'left');
      expect(survivor.noteCount, 1);
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
    test('removes only the targeted pair', () async {
      await repo.addNoteToManas('m1', 'n');
      await repo.addNoteToManas('m2', 'n');
      await repo.addNoteToManas('m1', 'other');

      await repo.removeNoteFromManas('m1', 'n');

      final remaining = await isar.manasNoteLinkModels.where().findAll();
      final pairs = remaining
          .map((l) => '${l.manasId}/${l.noteId}')
          .toSet();
      expect(pairs, {'m2/n', 'm1/other'});
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
