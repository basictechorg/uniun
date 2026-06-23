import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/manthan_card_status.dart';

part 'manthan_card_entity.freezed.dart';

@freezed
abstract class ManthanCardEntity with _$ManthanCardEntity {
  const factory ManthanCardEntity({
    required String scopeId,
    required String signature,
    required List<String> noteIds,
    required String generatedParagraph,
    required ManthanCardStatus status,
    required DateTime createdAt,
    DateTime? lastSeenAt,
    // In-memory only (footer snippets); not persisted to Isar.
    @Default(<String>[]) List<String> provenanceLabels,
  }) = _ManthanCardEntity;
}
