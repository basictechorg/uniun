class PrivateGroupJoinRequestEntity {
  final int id;
  final String eventId;
  final String groupId;
  final String senderPubkey;
  final String keyPackageB64;
  final DateTime timestamp;

  PrivateGroupJoinRequestEntity({
    required this.id,
    required this.eventId,
    required this.groupId,
    required this.senderPubkey,
    required this.keyPackageB64,
    required this.timestamp,
  });
}
