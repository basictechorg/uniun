import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';

@Injectable(as: NoteResolverRepository)
class NoteResolverRepositoryImpl implements NoteResolverRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  NoteResolverRepositoryImpl({required this.isar, required NoteRelationRepository relations})
      : _relations = relations;

  /// Maps a row to its domain entity with live edge-table counts attached.
  /// The resolver feeds the thread root + parent/mention/reply cards, all of
  /// which read [NoteEntity.referenceCount] / [NoteEntity.cachedReplyCount].
  Future<NoteEntity> _withCounts(NoteModel m) async => m.toDomain().copyWith(
        cachedReplyCount: await _relations.replyCount(m.eventId),
        referenceCount: await _relations.referenceCount(m.eventId),
      );

  /// Resolves a single NIP-18 quoted note, if any. Cheap fall-through when
  /// [note.quoteEventId] is null. Batched callers should use [enrichWithQuotes].
  Future<NoteEntity> _enrichQuote(NoteEntity note) async {
    final qid = note.quoteEventId;
    if (qid == null) return note;
    final row = await isar.noteModels.where().eventIdEqualTo(qid).findFirst();
    if (row == null) return note;
    return note.copyWith(quotedNote: row.toDomain());
  }

  @override
  Future<Either<Failure, NoteEntity>> resolveById(String id) async {
    try {
      final note =
          await isar.noteModels.where().eventIdEqualTo(id).findFirst();
      if (note != null) {
        return Right(await _enrichQuote(await _withCounts(note)));
      }

      return Left(Failure.notFoundFailure('Note not found: $id'));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, NoteEntity?>> resolveNoteById(String id) async {
    final result = await resolveById(id);
    // Not-found resolves to null rather than an error (parent/mention may be
    // absent locally); only real failures propagate.
    return result.fold((_) => const Right(null), (r) => Right(r));
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> resolveReplies(String id) async {
    try {
      final replies = await isar.noteModels
          .filter()
          .replyToEventIdEqualTo(id)
          .findAll();
      final out = [for (final m in replies) await _withCounts(m)]
        ..sort((a, b) => a.created.compareTo(b.created));
      return Right(await enrichWithQuotes(out));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NoteEntity>>> resolveMany(
      List<String> ids) async {
    try {
      final out = <NoteEntity>[];
      for (final id in ids) {
        final r = await resolveNoteById(id);
        r.fold((_) {}, (note) {
          if (note != null) out.add(note);
        });
      }
      // resolveNoteById → resolveById already enriches each entity; no second pass needed.
      return Right(out);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<List<NoteEntity>> enrichWithQuotes(List<NoteEntity> notes) async {
    if (notes.isEmpty) return notes;
    final quoteIds = <String>{
      for (final n in notes)
        if (n.quoteEventId != null) n.quoteEventId!,
    };
    if (quoteIds.isEmpty) return notes;

    final rows = await isar.noteModels
        .filter()
        .anyOf(quoteIds, (q, id) => q.eventIdEqualTo(id))
        .findAll();
    final byId = {for (final m in rows) m.eventId: m.toDomain()};

    return [
      for (final n in notes)
        n.quoteEventId == null ? n : n.copyWith(quotedNote: byId[n.quoteEventId]),
    ];
  }
}
