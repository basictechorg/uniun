// lib/data/models/manthan/manthan_card_model.dart
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/manthan_card_status.dart';
import 'package:uniun/domain/entities/manthan/manthan_card_entity.dart';

part 'manthan_card_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('ManthanCard')
class ManthanCardModel {
  Id id = Isar.autoIncrement;

  /// Dedup scope key: 'all', or a sha1 of sorted manasIds. Composite-unique
  /// with [signature] so the same combination never persists twice per scope.
  @Index(composite: [CompositeIndex('signature')], unique: true)
  late String scopeId;

  late String signature; // sha256(sortedNoteIds.join('|'))

  late List<String> noteIds; // 2-3 contributing source-note ids (sorted)

  late String generatedParagraph;

  @Index()
  late String status; // ManthanCardStatus.name

  late DateTime createdAt;

  DateTime? lastSeenAt; // stamped on every swipe; drives oldest-first resurfacing
}

extension ManthanCardModelX on ManthanCardModel {
  ManthanCardEntity toDomain() => ManthanCardEntity(
        scopeId: scopeId,
        signature: signature,
        noteIds: noteIds,
        generatedParagraph: generatedParagraph,
        status: ManthanCardStatus.values.byName(status),
        createdAt: createdAt,
        lastSeenAt: lastSeenAt,
      );
}
