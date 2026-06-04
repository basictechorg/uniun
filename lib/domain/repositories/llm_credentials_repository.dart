import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

/// Lets the Settings UI manage cloud LLM API keys.
///
/// Backed by [flutter_secure_storage]. Keys never leave the device keychain.
abstract class LlmCredentialsRepository {
  Future<Either<Failure, Unit>> saveOpenRouterKey(String key);
  Future<Either<Failure, Unit>> clearOpenRouterKey();
  Future<Either<Failure, String?>> getOpenRouterKey();
  Future<bool> hasOpenRouterKey();
}
