import 'package:isar_community/isar.dart';

part 'private_channel_message_model.g.dart';

/// Stores the successfully decrypted messages that the user sees in the chat UI.
@Collection(ignore: {'copyWith'})
@Name('PrivateChannelMessage')
class PrivateChannelMessageModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  /// The NIP-29 group ID format: <host>'<group-id>
  @Index()
  late String groupId;

  late String senderPubkey;
  late String decryptedContent;

  /// Used to indicate replies and root events, matching normal channel messages
  late List<String> eTagRefs;
  
  @Index()
  String? rootEventId;

  @Index()
  String? replyToEventId;

  late List<String> pTagRefs;

  late DateTime timestamp;
}
