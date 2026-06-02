import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/repositories/relay_repository.dart';

@lazySingleton
class DeleteRelayUseCase extends UseCase<Either<Failure, Unit>, String> {
  final RelayRepository repository;

  const DeleteRelayUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String url, {bool cached = false}) {
    return repository.delete(url.trim());
  }
}
