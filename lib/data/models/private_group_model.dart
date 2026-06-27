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
}
