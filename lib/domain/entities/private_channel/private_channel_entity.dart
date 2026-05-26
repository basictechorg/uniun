class PrivateChannelEntity {
  final int id;
  final String groupId;
  final String mlsGroupId;
  final String name;
  final String description;
  final List<String> relays;
  final String adminPubkey;

  PrivateChannelEntity({
    required this.id,
    required this.groupId,
    required this.mlsGroupId,
    required this.relays,
    required this.name,
    required this.description,
    required this.adminPubkey,
  });
}
