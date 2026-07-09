import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/repositories/surrounding_note_repository.dart';

// ── DeleteSurroundingNoteUseCase ──────────────────────────────────────────────

/// Removes a Surrounding-feed note from the user's view (deletes it from the
/// ephemeral cache + writes a 1-day tombstone so the mesh doesn't re-store it).
@lazySingleton
class DeleteSurroundingNoteUseCase extends UseCase<Either<Failure, Unit>, String> {
  final SurroundingNoteRepository _repository;
  const DeleteSurroundingNoteUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String eventId, {bool cached = false}) {
    return _repository.delete(eventId);
  }
}
