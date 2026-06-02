import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/llm/llm_credentials_data_source.dart';
import 'package:uniun/data/datasources/llm/remote_llm_data_source.dart';
import 'package:uniun/domain/repositories/llm_credentials_repository.dart';

@Injectable(as: LlmCredentialsRepository)
class LlmCredentialsRepositoryImpl implements LlmCredentialsRepository {
  final LlmCredentialsDataSource _store;
  final RemoteLlmDataSource _remote;

  LlmCredentialsRepositoryImpl(this._store, this._remote);

  @override
  Future<Either<Failure, Unit>> saveOpenRouterKey(String key) async {
    try {
      await _store.setOpenRouterKey(key.trim());
      // Drop the cached HTTP client so the next call rebuilds with the
      // new credential.
      _remote.invalidateClient();
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearOpenRouterKey() async {
    try {
      await _store.clearOpenRouterKey();
      _remote.invalidateClient();
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> getOpenRouterKey() async {
    try {
      return Right(await _store.getOpenRouterKey());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<bool> hasOpenRouterKey() => _store.hasOpenRouterKey();
}
