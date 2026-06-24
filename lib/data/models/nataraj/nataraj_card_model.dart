// lib/data/models/nataraj/nataraj_card_model.dart
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';

part 'nataraj_card_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('NatarajCard')
class NatarajCardModel {
  Id id = Isar.autoIncrement;

  /// Dedup scope key: 'all', or a sha1 of sorted manasIds. Composite-unique
  /// with [signature] so the same combination never persists twice per scope.
  @Index(composite: [CompositeIndex('signature')], unique: true)
  late String scopeId;

  late String signature; // sha256(sortedNoteIds.join('|'))

  late List<String> noteIds; // 2-3 contributing source-note ids (sorted)

  late String generatedParagraph;

  @Index()
  late String status; // NatarajCardStatus.name

  late DateTime createdAt;

  DateTime? lastSeenAt; // stamped on every swipe; drives oldest-first resurfacing
}

extension NatarajCardModelX on NatarajCardModel {
  NatarajCardEntity toDomain() => NatarajCardEntity(
        scopeId: scopeId,
        signature: signature,
        noteIds: noteIds,
        generatedParagraph: generatedParagraph,
        status: NatarajCardStatus.values.byName(status),
        createdAt: createdAt,
        lastSeenAt: lastSeenAt,
      );
}
