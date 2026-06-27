import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../_helpers/isar_test_harness.dart';

/// getOwnNotes feeds the Brahma graph (own nodes). Its entities must carry the
/// edge-table counts so the node bottom sheet shows the real reference/comment
/// numbers — the same enrichment getFeed already does.
void main() {
  late Isar isar;
  late NoteRepositoryImpl repo;

  setUp(() async {
    isar = await openTestIsar();
    final relations = NoteRelationRepositoryImpl(isar: isar);
    repo = NoteRepositoryImpl(
      isar: isar,
      relations: relations,
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  NoteModel ownNote(String id) => NoteModel(
        eventId: id,
        sig: 'sig',
        authorPubkey: 'mypub',
        content: 'hello',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      );

  NoteRelationModel edge(String parent, String child) => NoteRelationModel()
    ..parentId = parent
    ..childId = child
    ..createdAt = DateTime(2026, 1, 1);

  NoteEntity ownEntity(String id, {List<String> eTagRefs = const []}) =>
      NoteEntity(
        id: id,
        sig: 'sig',
        authorPubkey: 'mypub',
        content: 'c',
        type: NoteType.text,
        eTagRefs: eTagRefs,
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      );

  test('getOwnNotes stitches reference (outgoing) + comment (incoming) counts',
      () async {
    await isar.writeTxn(() async {
      await isar.noteModels.put(ownNote('A'));
      // A is referenced by two other notes → 2 incoming = comment count.
      await isar.noteRelationModels.put(edge('A', 'B'));
      await isar.noteRelationModels.put(edge('A', 'C'));
      // A references one note → 1 outgoing = reference count.
      await isar.noteRelationModels.put(edge('Z', 'A'));
    });

    final result = await repo.getOwnNotes('mypub');
    final note = result.getOrElse(() => []).single;

    expect(note.id, 'A');
    expect(note.cachedReplyCount, 2, reason: 'incoming references = comments');
    expect(note.referenceCount, 1, reason: 'outgoing references');
  });

  test('publishing a note that references another fills the edge table — the '
      'referenced note then shows the new note as a comment', () async {
    // Mirrors the Brahma flow: create A, then create B referencing A (mention).
    await repo.saveNote(ownEntity('A'));
    await repo.saveNote(ownEntity('B', eTagRefs: ['A']));

    final own = (await repo.getOwnNotes('mypub')).getOrElse(() => []);
    final a = own.firstWhere((n) => n.id == 'A');
    final b = own.firstWhere((n) => n.id == 'B');

    expect(a.cachedReplyCount, 1, reason: 'B is a comment on A');
    expect(b.referenceCount, 1, reason: 'B references A');
  });
}
