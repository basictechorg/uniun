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

  /// 1–3 hex color strings (`"#RRGGBB"`) chosen by the user. Empty = use
  /// the default saved-node colour. Distribution across this Manas's
  /// nodes is by stable hash of eventId — never per-render random.
  /// Only applies inside a Manas-scoped graph view; unscoped Brahma keeps
  /// its fixed saved/own/draft palette.
  List<String> colorHexes = const [];

  late DateTime createdAt;
  late DateTime updatedAt;
}

extension ManasModelExtension on ManasModel {
  ManasEntity toDomain({int noteCount = 0}) => ManasEntity(
        manasId: manasId,
        name: name,
        description: description,
        iconName: iconName,
        colorHexes: colorHexes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        noteCount: noteCount,
      );
}
