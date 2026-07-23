import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/cloud/uniun_cloud_auth.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/domain/repositories/llm_credentials_repository.dart';

@Injectable(as: LlmCredentialsRepository)
class LlmCredentialsRepositoryImpl implements LlmCredentialsRepository {
  final UniunCloudAuth _auth;
  final UniunGatewayClient _gateway;

  LlmCredentialsRepositoryImpl(this._auth, this._gateway);

  @override
  Future<Either<Failure, Unit>> connect() async {
    try {
      final key = await _auth.ensureApiKey();
      if (key == null) {
        return const Left(
            Failure.errorFailure('No active identity to sign in with'));
      }
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> disconnect({bool confirm = false}) async {
    try {
      await _auth.disconnect(confirm: confirm);
      return const Right(unit);
    } on UniunGatewayException catch (e) {
      if (e.statusCode == 409) {
        return const Left(Failure.errorFailure('last_active_key'));
      }
      return Left(Failure.errorFailure(e.toString()));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<bool> isConnected() => _auth.hasStoredKey();

  @override
  Future<Either<Failure, ({String plan, num balance})>> accountStatus() async {
    try {
      final key = await _auth.ensureApiKey();
      if (key == null) {
        return const Left(Failure.errorFailure('Not connected'));
      }
      final credits = await _gateway.getCredits(key);
      return Right((
        plan: (credits['plan'] as String?) ?? 'free',
        balance: (credits['balance'] as num?) ?? 0,
      ));
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
