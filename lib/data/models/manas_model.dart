import 'package:isar_community/isar.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';

part 'manas_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('Manas')
class ManasModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String manasId;

  late String name;
  String? description;

  /// Material icon name (e.g. `account_balance`). Resolved at render time
  /// against the curated `ManasIcons` registry. Null = use the fallback.
  String? iconName;

  late DateTime createdAt;
  late DateTime updatedAt;

  /// Signed+encrypted Nostr Kind 30510 event for this row (§3). Nullable
  /// during Phase 0a migration.
  String? signedNostrEvent;

  /// Tombstone marker (§5a). Null on active Manases.
  @Index()
  DateTime? removedAt;
}

extension ManasModelExtension on ManasModel {
  ManasEntity toDomain({int noteCount = 0}) => ManasEntity(
        manasId: manasId,
        name: name,
        description: description,
        iconName: iconName,
        createdAt: createdAt,
        updatedAt: updatedAt,
        noteCount: noteCount,
      );
}
