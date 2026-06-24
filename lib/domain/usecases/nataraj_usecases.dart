// lib/domain/usecases/nataraj_usecases.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/repositories/nataraj_repository.dart';

@lazySingleton
class GetNextNatarajCardUseCase
    extends UseCase<Either<Failure, NatarajCardEntity?>, String> {
  final NatarajRepository repository;
  GetNextNatarajCardUseCase(this.repository);

  @override
  Future<Either<Failure, NatarajCardEntity?>> call(String scopeId,
          {bool cached = false}) =>
      repository.nextBufferedCard(scopeId);
}

class RecordNatarajSwipeInput {
  final String scopeId;
  final String signature;
  final NatarajCardStatus status;
  const RecordNatarajSwipeInput({
    required this.scopeId,
    required this.signature,
    required this.status,
  });
}

@lazySingleton
class RecordNatarajSwipeUseCase
    extends UseCase<Either<Failure, Unit>, RecordNatarajSwipeInput> {
  final NatarajRepository repository;
  RecordNatarajSwipeUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RecordNatarajSwipeInput input,
          {bool cached = false}) =>
      repository.updateStatus(input.scopeId, input.signature, input.status);
}

@lazySingleton
class CountBufferedNatarajCardsUseCase
    extends UseCase<Either<Failure, int>, String> {
  final NatarajRepository repository;
  CountBufferedNatarajCardsUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(String scopeId, {bool cached = false}) =>
      repository.countByStatus(scopeId, NatarajCardStatus.buffered);
}
