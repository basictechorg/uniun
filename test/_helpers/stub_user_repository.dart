import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/user_key/user_key_entity.dart';
import 'package:uniun/domain/repositories/user_repository.dart';

import 'fixtures.dart';

/// Deterministic [UserRepository] test double.
///
/// Only [getActiveKeysHex] is meaningful — the four bech32-domain methods
/// throw [UnimplementedError] because tests that use this stub don't
/// exercise them. Set [keys] to `null` to simulate a logged-out identity.
class StubUserRepository implements UserRepository {
  ({String privkeyHex, String pubkeyHex})? keys = (
    privkeyHex: kTestPrivHex,
    pubkeyHex: kTestPubHex,
  );

  @override
  Future<({String privkeyHex, String pubkeyHex})?> getActiveKeysHex() async =>
      keys;

  @override
  Future<Either<Failure, UserKeyEntity>> generateKey() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserKeyEntity>> getActiveUser() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserKeyEntity>> importKey(String nsec) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> logout() => throw UnimplementedError();
}
