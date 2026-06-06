import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/note_repository.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';

@Injectable(as: NoteRepository)
class NoteRepositoryImpl extends NoteRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  final NoteResolverRepository _resolver;

  NoteRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
    required NoteResolverRepository resolver,
  })  : _relations = relations,
        _resolver = resolver;

  @override
  Future<Either<Failure, List<NoteEntity>>> getFeed({
    required int limit,
    DateTime? before,
  }) async {
    try {
      // Feed shows every note — top-level posts, replies, and references.
      // Replies and refs are also notes; they belong in the stream.
      final notes = before != null
          ? await isar.noteModels
                .filter()
                .createdLessThan(before)
                .sortByCreatedDesc()
                .limit(limit)
                .findAll()
          : await isar.noteModels
                .where()
                .sortByCreatedDesc()
                .limit(limit)
                .findAll();

      return Right(await _withReplyCounts(notes));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  /// Stitches the live reply + reference counts onto each entity from the
  /// edge table. Indexed count queries — fast even with many notes.
  Future<List<NoteEntity>> _withReplyCounts(List<NoteModel> models) async {
    final entities = models.map((n) => n.toDomain()).toList();
    final base = <NoteEntity>[
      for (final e in entities)
        e.copyWith(
          cachedReplyCount: await _relations.replyCount(e.id),
          referenceCount: await _relations.referenceCount(e.id),
        ),
    ];
    return _resolver.enrichWithQuotes(base);
  }

  @override
  Future<Either<Failure, NoteEntity>> getNoteById(String eventId) async {
    try {
      final note = await isar.noteModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      if (note == null) {
        return const Left(Failure.errorFailure('Note not found'));
      }
      final enriched = await _resolver.enrichWithQuotes([note.toDomain()]);
      return Right(enriched.first.copyWith(
            cachedReplyCount: await _relations.replyCount(eventId),
            referenceCount: await _relations.referenceCount(eventId),
          ));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> getReplies(String eventId) async {
    try {
      // NIP-10 replies: this event is the immediate parent.
      final byReplyTo = await isar.noteModels
          .filter()
          .replyToEventIdEqualTo(eventId)
          .sortByCreated()
          .findAll();

      // Root-only e-tag children (["e", root, "", "root"]) where
      // replyToEventId stays null — must appear in the root's reply list too.
      final rootTagOnly = await isar.noteModels
          .filter()
          .rootEventIdEqualTo(eventId)
          .replyToEventIdIsNull()
          .sortByCreated()
          .findAll();

      // Incoming eTagRef mentions: notes whose eTagRefs list contains this
      // event, but which are not already NIP-10 reply/root children.
      final mentions = await isar.noteModels
          .filter()
          .eTagRefsElementEqualTo(eventId)
          .not()
          .replyToEventIdEqualTo(eventId)
          .not()
          .rootEventIdEqualTo(eventId)
          .sortByCreated()
          .findAll();

      final byEventId = <String, NoteModel>{};
      for (final n in [...byReplyTo, ...rootTagOnly, ...mentions]) {
        if (n.eventId != eventId) byEventId[n.eventId] = n;
      }

      final merged = byEventId.values.toList()
        ..sort((a, b) => a.created.compareTo(b.created));
      return Right(await _withReplyCounts(merged));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> getThread(
    String rootEventId,
  ) async {
    try {
      // Root note
      final root = await isar.noteModels
          .where()
          .eventIdEqualTo(rootEventId)
          .findFirst();

      // All notes in the thread (rootEventId == rootEventId), chronological
      final replies = await isar.noteModels
          .filter()
          .rootEventIdEqualTo(rootEventId)
          .sortByCreated()
          .findAll();

      final all = [if (root != null) root, ...replies];

      return Right(await _withReplyCounts(all));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, NoteEntity>> saveNote(NoteEntity note) async {
    try {
      final existing = await isar.noteModels
          .where()
          .eventIdEqualTo(note.id)
          .findFirst();

      if (existing != null) {
        return Right(existing.toDomain());
      }

      final model = NoteModel(
        eventId: note.id,
        sig: note.sig,
        authorPubkey: note.authorPubkey,
        content: note.content,
        subject: note.subject,
        type: note.type,
        eTagRefs: note.eTagRefs,
        rootEventId: note.rootEventId,
        replyToEventId: note.replyToEventId,
        pTagRefs: note.pTagRefs,
        tTags: note.tTags,
        created: note.created,
        quoteEventId: note.quoteEventId,
      );

      final parents = replyEdgeParentIds(
        replyToEventId: note.replyToEventId,
        rootEventId: note.rootEventId,
        eTagRefs: note.eTagRefs,
      );
      await isar.writeTxn(() async {
        await isar.noteModels.put(model);
        await _relations.addEdgesInTxn(parents: parents, childId: note.id);
      });

      return Right(model.toDomain().copyWith(
            cachedReplyCount: await _relations.replyCount(note.id),
            referenceCount: await _relations.referenceCount(note.id),
          ));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getReplyCount(String eventId) async {
    try {
      return Right(await _relations.replyCount(eventId));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getThreadReplyCount(String rootEventId) async {
    try {
      final count = await isar.noteModels
          .filter()
          .rootEventIdEqualTo(rootEventId)
          .count();
      return Right(count);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> getOwnNotes(
    String pubkeyHex,
  ) async {
    try {
      final notes = await isar.noteModels
          .filter()
          .authorPubkeyEqualTo(pubkeyHex)
          .sortByCreatedDesc()
          .findAll();
      final entities = notes.map((m) => m.toDomain()).toList();
      return Right(await _resolver.enrichWithQuotes(entities));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> searchNotes(String query) async {
    try {
      if (query.trim().isEmpty) return const Right([]);
      final results = await isar.noteModels
          .filter()
          .contentContains(query.trim(), caseSensitive: false)
          .sortByCreatedDesc()
          .limit(30)
          .findAll();
      final entities = results.map((m) => m.toDomain()).toList();
      return Right(await _resolver.enrichWithQuotes(entities));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

}
