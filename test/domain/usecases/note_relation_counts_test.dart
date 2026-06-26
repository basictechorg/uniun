import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';

import '../../_helpers/isar_test_harness.dart';

/// The Brahma graph reads counts through this use case so a node's comment
/// count is GLOBAL — it counts every note that references it, including the
/// user's own unsaved notes (the saved-scoped count would miss those).
void main() {
  late Isar isar;
  late GetNoteRelationCountsUseCase usecase;

  setUp(() async {
    isar = await openTestIsar();
    usecase = GetNoteRelationCountsUseCase(NoteRelationRepositoryImpl(isar: isar));
  });

  tearDown(() async => isar.close(deleteFromDisk: true));

  NoteRelationModel edge(String parent, String child) => NoteRelationModel()
    ..parentId = parent
    ..childId = child
    ..createdAt = DateTime(2026, 1, 1);

  test('counts every referencing note globally, saved or not', () async {
    await isar.writeTxn(() async {
      // A is referenced by B and C (neither needs to be saved).
      await isar.noteRelationModels.put(edge('A', 'B'));
      await isar.noteRelationModels.put(edge('A', 'C'));
      // A references one note Z.
      await isar.noteRelationModels.put(edge('Z', 'A'));
    });

    final result = await usecase.call(['A', 'Z']);
    final map = result.getOrElse(() => {});

    expect(map['A']!.comments, 2, reason: 'B and C reference A → 2 comments');
    expect(map['A']!.references, 1, reason: 'A references Z → 1 reference');
    expect(map['Z']!.comments, 1, reason: 'A references Z → Z has 1 comment');
    expect(map['Z']!.references, 0);
  });
}
