import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/repositories/share_repository.dart';

@lazySingleton
class ShareNoteUseCase extends UseCase<Either<Failure, Unit>, ShareNoteInput> {
  final ShareRepository _repository;
  const ShareNoteUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(
    ShareNoteInput input, {
    bool cached = false,
  }) =>
      _repository.shareNote(input);
}
