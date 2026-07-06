import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/user_key/user_key_entity.dart';
import 'package:uniun/domain/repositories/user_repository.dart';

import 'fixtures.dart';

/// Deterministic [UserRepository] test double.
///
/// [getActiveKeysHex] and [getActiveUser] both derive from [keys] — set it
/// to `null` to simulate a logged-out identity (hex → null, user → Left).
/// The remaining bech32-domain methods throw [UnimplementedError] because
/// tests that use this stub don't exercise them.
class StubUserRepository implements UserRepository {
  ({String privkeyHex, String pubkeyHex})? keys = (
    privkeyHex: kTestPrivHex,
    pubkeyHex: kTestPubHex,
  );

  @override
  Future<({String privkeyHex, String pubkeyHex})?> getActiveKeysHex() async =>
      keys;

  @override
  Future<Either<Failure, UserKeyEntity>> getActiveUser() async =>
      keys == null
          ? const Left(Failure.notFoundFailure('no active user'))
          : Right(aUserKey(pubkeyHex: keys!.pubkeyHex));

  @override
  Future<Either<Failure, UserKeyEntity>> generateKey() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserKeyEntity>> importKey(String nsec) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> logout() => throw UnimplementedError();
}
