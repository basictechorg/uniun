import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

import '../../_helpers/isar_test_harness.dart';

/// The thread page renders comments via resolveReplies. A "comment" is any note
/// that references the root in the edge table — NIP-10 replies AND mention-
/// references — so it must match the comment count, not just NIP-10 markers.
void main() {
  late Isar isar;
  late NoteRepositoryImpl repo;
  late NoteResolverRepositoryImpl resolver;

  setUp(() async {
    isar = await openTestIsar();
    final relations = NoteRelationRepositoryImpl(isar: isar);
    resolver = NoteResolverRepositoryImpl(
      isar: isar,
      relations: relations,
      attachments: NoteAttachmentsEnricher(isar: isar),
    );
    repo = NoteRepositoryImpl(
      isar: isar,
      relations: relations,
      resolver: resolver,
    );
  });

  tearDown(() async => isar.close(deleteFromDisk: true));

  NoteEntity note(String id,
          {List<String> eTagRefs = const [],
          String? rootEventId,
          String? replyToEventId}) =>
      NoteEntity(
        id: id,
        sig: 'sig',
        authorPubkey: 'pub',
        content: 'c',
        type: NoteType.text,
        eTagRefs: eTagRefs,
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
      );

  test('a mention-reference shows up as a comment in the root thread', () async {
    await repo.saveNote(note('A'));
    // B references A via a mention (no NIP-10 reply marker) — the Brahma
    // "add reference" flow.
    await repo.saveNote(note('B', eTagRefs: ['A']));
    // C is a genuine NIP-10 reply to A.
    await repo.saveNote(note('C', eTagRefs: ['A'], replyToEventId: 'A'));

    final replies = (await resolver.resolveReplies('A')).getOrElse(() => []);
    final ids = replies.map((n) => n.id).toSet();

    expect(ids, {'B', 'C'},
        reason: 'thread shows every note that references A (mention + reply)');
  });
}
