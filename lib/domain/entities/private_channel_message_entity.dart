class PrivateChannelMessageEntity {
  final int id;
  final String eventId;
  final String groupId;
  final String senderPubkey;
  final String decryptedContent;
  final DateTime timestamp;

  PrivateChannelMessageEntity({
    required this.id,
    required this.eventId,
    required this.groupId,
    required this.senderPubkey,
    required this.decryptedContent,
    required this.timestamp,
  });
}
