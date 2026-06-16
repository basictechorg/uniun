import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

abstract class UserServerListRepository {
  /// Active user's preferred Blossom server URLs, in priority order. Empty
  /// list = nothing configured yet; callers fall back to the hardcoded
  /// backend URL (`AppConstants.kUniunBlossom`).
  Future<Either<Failure, List<String>>> getServers();

  /// Replace the local snapshot and enqueue a Kind 10063 publish so the
  /// network sees the new server list. Per-device — no inbound
  /// reconciliation; cross-device sync is out of scope.
  Future<Either<Failure, Unit>> setServers(List<String> serverUrls);
}
