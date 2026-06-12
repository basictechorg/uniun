import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

abstract class UserServerListRepository {
  /// Active user's preferred Blossom server URLs, in priority order. Empty
  /// list = nothing published yet; callers fall back to the hardcoded
  /// backend URL.
  Future<Either<Failure, List<String>>> getServers();

  /// Replace the local snapshot and enqueue a Kind 10063 publish.
  Future<Either<Failure, Unit>> setServers(List<String> serverUrls);

  /// Inbound reconciliation from a Kind 10063 event.
  Future<Either<Failure, Unit>> reconcileFromEvent({
    required String pubkey,
    required DateTime createdAt,
    required List<String> serverUrls,
  });
}
