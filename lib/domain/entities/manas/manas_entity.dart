import 'package:freezed_annotation/freezed_annotation.dart';

part 'manas_entity.freezed.dart';

@freezed
abstract class ManasEntity with _$ManasEntity {
  const factory ManasEntity({
    required String manasId,
    required String name,
    String? description,
    String? iconName,
    @Default(<String>[]) List<String> colorHexes,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int noteCount,
  }) = _ManasEntity;
}
