import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/domain/repositories/app_settings_repository.dart';

@Injectable(as: AppSettingsRepository)
class AppSettingsRepositoryImpl implements AppSettingsRepository {
  final AppSettingsStore _store;

  AppSettingsRepositoryImpl(this._store);

  @override
  Future<Either<Failure, bool>> getManthanCoachSeen() async {
    try {
      return Right(_store.manthanCoachSeen);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setManthanCoachSeen(bool seen) async {
    try {
      await _store.setManthanCoachSeen(seen);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int?>> getAutoDeleteOldNotesDays() async {
    try {
      return Right(_store.autoDeleteOldNotesDays);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setAutoDeleteOldNotesDays(int? days) async {
    try {
      await _store.setAutoDeleteOldNotesDays(days);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getRecentSyncWindowDays() async {
    try {
      return Right(_store.recentSyncWindowDays);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setRecentSyncWindowDays(int days) async {
    try {
      await _store.setRecentSyncWindowDays(days);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
