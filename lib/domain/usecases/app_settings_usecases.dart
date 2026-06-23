import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/repositories/app_settings_repository.dart';

/// Reads whether the Manthan first-run coach overlay has been dismissed.
@lazySingleton
class GetManthanCoachSeenUseCase
    extends NoParamsUseCase<Either<Failure, bool>> {
  final AppSettingsRepository _repository;
  const GetManthanCoachSeenUseCase(this._repository);

  @override
  Future<Either<Failure, bool>> call() => _repository.getManthanCoachSeen();
}

/// Persists that the Manthan coach overlay has been seen/dismissed.
@lazySingleton
class SetManthanCoachSeenUseCase extends UseCase<Either<Failure, Unit>, bool> {
  final AppSettingsRepository _repository;
  const SetManthanCoachSeenUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(bool input, {bool cached = false}) =>
      _repository.setManthanCoachSeen(input);
}

/// Reads the auto-delete retention window for short-lived public notes
/// (`null` = disabled).
@lazySingleton
class GetAutoDeleteOldNotesDaysUseCase
    extends NoParamsUseCase<Either<Failure, int?>> {
  final AppSettingsRepository _repository;
  const GetAutoDeleteOldNotesDaysUseCase(this._repository);

  @override
  Future<Either<Failure, int?>> call() =>
      _repository.getAutoDeleteOldNotesDays();
}

/// Persists the auto-delete retention window (`null` = off).
@lazySingleton
class SetAutoDeleteOldNotesDaysUseCase
    extends UseCase<Either<Failure, Unit>, int?> {
  final AppSettingsRepository _repository;
  const SetAutoDeleteOldNotesDaysUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(int? input, {bool cached = false}) =>
      _repository.setAutoDeleteOldNotesDays(input);
}

/// Reads the recent-sync window (days of history the capped surfaces pull;
/// defaults to 7).
@lazySingleton
class GetRecentSyncWindowDaysUseCase
    extends NoParamsUseCase<Either<Failure, int>> {
  final AppSettingsRepository _repository;
  const GetRecentSyncWindowDaysUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call() =>
      _repository.getRecentSyncWindowDays();
}

/// Persists the recent-sync window (days of history the capped surfaces pull).
@lazySingleton
class SetRecentSyncWindowDaysUseCase
    extends UseCase<Either<Failure, Unit>, int> {
  final AppSettingsRepository _repository;
  const SetRecentSyncWindowDaysUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(int input, {bool cached = false}) =>
      _repository.setRecentSyncWindowDays(input);
}
