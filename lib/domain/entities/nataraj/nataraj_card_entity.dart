import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';

part 'nataraj_card_entity.freezed.dart';

@freezed
abstract class NatarajCardEntity with _$NatarajCardEntity {
  const factory NatarajCardEntity({
    required String scopeId,
    required String signature,
    required List<String> noteIds,
    required String generatedParagraph,
    required NatarajCardStatus status,
    required DateTime createdAt,
    DateTime? lastSeenAt,
    // In-memory only (footer snippets); not persisted to Isar.
    @Default(<String>[]) List<String> provenanceLabels,
  }) = _NatarajCardEntity;
}
