// lib/domain/usecases/manthan_usecases.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/enum/manthan_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/manthan/manthan_card_entity.dart';
import 'package:uniun/domain/repositories/manthan_repository.dart';

@lazySingleton
class GetNextManthanCardUseCase
    extends UseCase<Either<Failure, ManthanCardEntity?>, String> {
  final ManthanRepository repository;
  GetNextManthanCardUseCase(this.repository);

  @override
  Future<Either<Failure, ManthanCardEntity?>> call(String scopeId,
          {bool cached = false}) =>
      repository.nextBufferedCard(scopeId);
}

class RecordManthanSwipeInput {
  final String scopeId;
  final String signature;
  final ManthanCardStatus status;
  const RecordManthanSwipeInput({
    required this.scopeId,
    required this.signature,
    required this.status,
  });
}

@lazySingleton
class RecordManthanSwipeUseCase
    extends UseCase<Either<Failure, Unit>, RecordManthanSwipeInput> {
  final ManthanRepository repository;
  RecordManthanSwipeUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(RecordManthanSwipeInput input,
          {bool cached = false}) =>
      repository.updateStatus(input.scopeId, input.signature, input.status);
}

@lazySingleton
class CountBufferedManthanCardsUseCase
    extends UseCase<Either<Failure, int>, String> {
  final ManthanRepository repository;
  CountBufferedManthanCardsUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(String scopeId, {bool cached = false}) =>
      repository.countByStatus(scopeId, ManthanCardStatus.buffered);
}
