import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';
import 'package:uniun/domain/repositories/report_repository.dart';

class ReportNoteInput {
  final String targetEventId;
  final String targetPubkey;
  final ReportType type;
  final String content;

  const ReportNoteInput({
    required this.targetEventId,
    required this.targetPubkey,
    required this.type,
    this.content = '',
  });
}

class ReportUserInput {
  final String targetPubkey;
  final ReportType type;
  final String content;

  const ReportUserInput({
    required this.targetPubkey,
    required this.type,
    this.content = '',
  });
}

@lazySingleton
class ReportNoteUseCase
    extends UseCase<Either<Failure, ReportEntity>, ReportNoteInput> {
  final ReportRepository _repository;
  const ReportNoteUseCase(this._repository);

  @override
  Future<Either<Failure, ReportEntity>> call(
    ReportNoteInput input, {
    bool cached = false,
  }) {
    return _repository.reportNote(
      targetEventId: input.targetEventId,
      targetPubkey: input.targetPubkey,
      type: input.type,
      content: input.content,
    );
  }
}

@lazySingleton
class ReportUserUseCase
    extends UseCase<Either<Failure, ReportEntity>, ReportUserInput> {
  final ReportRepository _repository;
  const ReportUserUseCase(this._repository);

  @override
  Future<Either<Failure, ReportEntity>> call(
    ReportUserInput input, {
    bool cached = false,
  }) {
    return _repository.reportUser(
      targetPubkey: input.targetPubkey,
      type: input.type,
      content: input.content,
    );
  }
}
