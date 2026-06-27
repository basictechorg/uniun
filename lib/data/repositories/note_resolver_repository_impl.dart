import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';

@Injectable(as: NoteResolverRepository)
class NoteResolverRepositoryImpl implements NoteResolverRepository {
  final Isar isar;
  final NoteRelationRepository _relations;
  final NoteAttachmentsEnricher _attachments;
  NoteResolverRepositoryImpl({
    required this.isar,
    required NoteRelationRepository relations,
    required NoteAttachmentsEnricher attachments,
  })  : _relations = relations,
        _attachments = attachments;

  /// Maps a row to its domain entity with live edge-table counts attached.
  /// The resolver feeds the thread root + parent/mention/reply cards, all of
  /// which read [NoteEntity.referenceCount] / [NoteEntity.cachedReplyCount].
  Future<NoteEntity> _withCounts(NoteModel m) async => m.toDomain().copyWith(
        cachedReplyCount: await _relations.replyCount(m.eventId),
        referenceCount: await _relations.referenceCount(m.eventId),
      );

  @override
  Future<Either<Failure, NoteEntity>> resolveById(String id) async {
    try {
      final note =
          await isar.noteModels.where().eventIdEqualTo(id).findFirst();
      if (note != null) {
        // quotedNote is built in NoteModel.toDomain() from the embeddedNoteJson
        // snapshot (no Isar lookup, retention-immune); only attachments need
        // local-cache enrichment.
        return Right(await _attachments.enrichOne(await _withCounts(note)));
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
      // A "comment" is any note that references [id] in the edge table — NIP-10
      // replies AND mention-references (the Brahma "add reference" flow). Read
      // from the edge table (childIdsOf) so this matches the comment count
      // exactly; `replyToEventIdEqualTo` alone would drop mention-references.
      // The edge table already excludes the thread root, so deep replies don't
      // surface here — they belong under their direct parent's thread.
      final childIds = await _relations.childIdsOf(id);
      if (childIds.isEmpty) return const Right([]);
      // Note: this returns only the child notes whose rows still exist in Isar.
      // `cachedReplyCount` counts edges, so if a child was evicted by retention
      // (or hasn't synced yet) the edge persists but its row is gone — the
      // thread reply list is then intentionally shorter than the comment badge.
      // The badge reflects the true reference count; this list reflects what is
      // actually renderable. The divergence is expected, not a bug.
      final replies = await isar.noteModels
          .filter()
          .anyOf(childIds.toSet(), (q, cid) => q.eventIdEqualTo(cid))
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
    // quotedNote is built in NoteModel.toDomain() from the embeddedNoteJson
    // snapshot (no Isar lookup, retention-immune). Only top-level attachments
    // still need local-cache enrichment.
    return _attachments.enrichAll(notes);
  }
}
