import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/repositories/channel_repository.dart';

@lazySingleton
class SaveChannelUseCase
    extends UseCase<Either<Failure, ChannelEntity>, ChannelEntity> {
  final ChannelRepository repository;
  const SaveChannelUseCase(this.repository);

  @override
  Future<Either<Failure, ChannelEntity>> call(
    ChannelEntity input, {
    bool cached = false,
  }) {
    return repository.saveChannel(input);
  }
}
