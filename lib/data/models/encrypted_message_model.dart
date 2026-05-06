import 'package:isar_community/isar.dart';

part 'encrypted_message_model.g.dart';

/// Stores raw encrypted Marmot payloads acting as a queue for decryption.
@Collection(ignore: {'copyWith'})
@Name('EncryptedMessage')
class EncryptedMessageModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  /// The NIP-29 group ID format: <host>'<group-id>
  @Index()
  late String groupId;

  late String senderPubkey;
  int kind = 9023;
  late String encryptedPayload;
  late DateTime timestamp;
}
