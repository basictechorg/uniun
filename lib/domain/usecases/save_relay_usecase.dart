import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/relay/relay_entity.dart';
import 'package:uniun/domain/repositories/relay_repository.dart';

@lazySingleton
class SaveRelayUseCase extends UseCase<Either<Failure, RelayEntity>, String> {
  final RelayRepository repository;

  const SaveRelayUseCase(this.repository);

  @override
  Future<Either<Failure, RelayEntity>> call(
    String input, {
    bool cached = false,
  }) {
    final trimmedUrl = input.trim();
    return repository.save(
      RelayEntity(
        url: trimmedUrl,
        read: true,
        write: true,
        status: RelayStatus.disconnected,
      ),
    );
  }
}
