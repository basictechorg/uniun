import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/repositories/manas_repository.dart';

/// Identifies a (Manas, note) pair for membership operations.
class ManasNoteLink {
  final String manasId;
  final String noteId;
  const ManasNoteLink(this.manasId, this.noteId);
}

@lazySingleton
class UpsertManasUseCase
    extends UseCase<Either<Failure, ManasEntity>, ManasEntity> {
  final ManasRepository repository;
  UpsertManasUseCase(this.repository);

  @override
  Future<Either<Failure, ManasEntity>> call(ManasEntity input,
      {bool cached = false}) {
    return repository.upsertManas(input);
  }
}

@lazySingleton
class GetManasListUseCase
    extends NoParamsUseCase<Either<Failure, List<ManasEntity>>> {
  final ManasRepository repository;
  GetManasListUseCase(this.repository);

  @override
  Future<Either<Failure, List<ManasEntity>>> call() {
    return repository.getManasList();
  }
}

@lazySingleton
class GetManasByIdUseCase
    extends UseCase<Either<Failure, ManasEntity>, String> {
  final ManasRepository repository;
  GetManasByIdUseCase(this.repository);

  @override
  Future<Either<Failure, ManasEntity>> call(String manasId,
      {bool cached = false}) {
    return repository.getManasById(manasId);
  }
}

@lazySingleton
class DeleteManasUseCase extends UseCase<Either<Failure, Unit>, String> {
  final ManasRepository repository;
  DeleteManasUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String manasId, {bool cached = false}) {
    return repository.deleteManas(manasId);
  }
}

@lazySingleton
class AddNoteToManasUseCase
    extends UseCase<Either<Failure, Unit>, ManasNoteLink> {
  final ManasRepository repository;
  AddNoteToManasUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ManasNoteLink input,
      {bool cached = false}) {
    return repository.addNoteToManas(input.manasId, input.noteId);
  }
}

@lazySingleton
class RemoveNoteFromManasUseCase
    extends UseCase<Either<Failure, Unit>, ManasNoteLink> {
  final ManasRepository repository;
  RemoveNoteFromManasUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ManasNoteLink input,
      {bool cached = false}) {
    return repository.removeNoteFromManas(input.manasId, input.noteId);
  }
}

@lazySingleton
class GetNoteIdsForManasUseCase
    extends UseCase<Either<Failure, List<String>>, String> {
  final ManasRepository repository;
  GetNoteIdsForManasUseCase(this.repository);

  @override
  Future<Either<Failure, List<String>>> call(String manasId,
      {bool cached = false}) {
    return repository.getNoteIdsForManas(manasId);
  }
}

@lazySingleton
class GetManasIdsForNoteUseCase
    extends UseCase<Either<Failure, List<String>>, String> {
  final ManasRepository repository;
  GetManasIdsForNoteUseCase(this.repository);

  @override
  Future<Either<Failure, List<String>>> call(String noteId,
      {bool cached = false}) {
    return repository.getManasIdsForNote(noteId);
  }
}
