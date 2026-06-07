import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/repositories/deleted_note_repository.dart';

// ── DeleteNoteUseCase ─────────────────────────────────────────────────────────

@lazySingleton
class DeleteNoteUseCase extends UseCase<Either<Failure, Unit>, String> {
  final DeletedNoteRepository _repository;
  const DeleteNoteUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String eventId, {bool cached = false}) {
    return _repository.deleteNote(eventId);
  }
}
