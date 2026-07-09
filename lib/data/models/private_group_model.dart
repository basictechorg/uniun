import 'package:isar_community/isar.dart';

part 'private_group_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('PrivateChannel') // on-disk name preserved across the channel→group rename
class PrivateGroupModel {
  Id id = Isar.autoIncrement;

  /// The NIP-29 group ID format: <host>'<group-id>
  @Index(unique: true)
  late String groupId;

  /// The OpenMLS internal group ID
  @Index()
  late String mlsGroupId;

  late List<String> relays;

  late String name;
  late String description;
  late String adminPubkey;

  /// Signed + NIP-44-self-encrypted Kind-30541 mesh event mirroring this
  /// private-group membership. Null for rows learned only from the relay /
  /// MLS transport before this device stamps them; the same-identity mesh
  /// advertises only rows that carry a signed event.
  String? signedNostrEvent;

  /// Tombstone marker for a left group. Null on active membership.
  @Index()
  DateTime? removedAt;
}
