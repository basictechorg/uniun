import 'package:isar_community/isar.dart';

part 'private_channel_join_request_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('PrivateChannelJoinRequest')
class PrivateChannelJoinRequestModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  @Index()
  late String groupId;

  late String senderPubkey;
  
  /// The base64 encoded KeyPackage
  late String keyPackageB64;
  
  late DateTime timestamp;
}
