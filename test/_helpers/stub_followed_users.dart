import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';
import 'package:uniun/domain/repositories/followed_user_repository.dart';

/// Deterministic [FollowedUserRepository] test double.
///
/// Only [getAllPubkeys] is meaningful — seed [pubkeys] before the test runs.
/// Set [leftOnGetAllPubkeys] to simulate the follow-list read failing. The
/// mutation methods throw [UnimplementedError] because tests that use this
/// stub don't exercise them.
class StubFollowedUsers implements FollowedUserRepository {
  List<String> pubkeys = const [];
  Failure? leftOnGetAllPubkeys;

  @override
  Future<Either<Failure, List<String>>> getAllPubkeys() async =>
      leftOnGetAllPubkeys != null
          ? Left(leftOnGetAllPubkeys!)
          : Right(List<String>.from(pubkeys));

  @override
  Future<Either<Failure, Unit>> followUser(
    String pubkeyHex, {
    String? relayHint,
    String? petname,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> followUsers(List<String> pubkeyHexes) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> unfollowUser(String pubkeyHex) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> isFollowing(String pubkeyHex) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<FollowedUserEntity>>> getAll() =>
      throw UnimplementedError();

  @override
  Stream<List<FollowedUserEntity>> watchFollowed() =>
      throw UnimplementedError();
}
