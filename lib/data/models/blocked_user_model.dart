import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';

part 'blocked_user_model.g.dart';

/// A pubkey the active identity has blocked. Stored locally only — the gateway
/// isolate keeps an in-memory set of these and drops every inbound event whose
/// `pubkey` matches, before persisting anything to Isar.
@Collection(ignore: {'copyWith'})
@Name('BlockedUser')
class BlockedUserModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String pubkeyHex;

  late DateTime blockedAt;
}

extension BlockedUserModelExtension on BlockedUserModel {
  BlockedUserEntity toDomain() => BlockedUserEntity(
        pubkeyHex: pubkeyHex,
        blockedAt: blockedAt,
      );
}
