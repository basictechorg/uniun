import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';

abstract class FollowedUserRepository {
  Future<Either<Failure, Unit>> followUser(
    String pubkeyHex, {
    String? relayHint,
    String? petname,
  });

  /// Follows several users at once, persisting all new follows in a single
  /// transaction and republishing the Kind-3 contact list **once** (instead of
  /// once per user). Used by the onboarding interest picker.
  Future<Either<Failure, Unit>> followUsers(List<String> pubkeyHexes);

  Future<Either<Failure, Unit>> unfollowUser(String pubkeyHex);

  Future<Either<Failure, bool>> isFollowing(String pubkeyHex);

  Future<Either<Failure, List<FollowedUserEntity>>> getAll();

  Future<Either<Failure, List<String>>> getAllPubkeys();

  Stream<List<FollowedUserEntity>> watchFollowed();
}
