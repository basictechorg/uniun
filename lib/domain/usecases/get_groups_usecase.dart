import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/repositories/group_repository.dart';

@lazySingleton
class GetGroupsUseCase
    extends NoParamsUseCase<Either<Failure, List<GroupEntity>>> {
  final GroupRepository repository;
  const GetGroupsUseCase(this.repository);

  @override
  Future<Either<Failure, List<GroupEntity>>> call() {
    return repository.getGroups();
  }
}
