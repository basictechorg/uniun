import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';

@Injectable(as: NoteResolverRepository)
class NoteResolverRepositoryImpl implements NoteResolverRepository {
  final Isar isar;
  NoteResolverRepositoryImpl({required this.isar});

  @override
  Future<Either<Failure, NoteEntity>> resolveById(String id) async {
    try {
      final note =
          await isar.noteModels.where().eventIdEqualTo(id).findFirst();
      if (note != null) {
        return Right(note.toDomain());
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
      final out = replies.map((m) => m.toDomain()).toList()
        ..sort((a, b) => a.created.compareTo(b.created));
      return Right(out);
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
      return Right(out);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
