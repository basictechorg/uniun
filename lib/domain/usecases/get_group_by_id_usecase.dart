import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/repositories/group_repository.dart';

@lazySingleton
class GetGroupByIdUseCase
    extends UseCase<Either<Failure, GroupEntity>, String> {
  final GroupRepository repository;
  const GetGroupByIdUseCase(this.repository);

  @override
  Future<Either<Failure, GroupEntity>> call(
    String input, {
    bool cached = false,
  }) {
    return repository.getGroupById(input);
  }
}
