import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/core/enum/report_type.dart';

part 'report_entity.freezed.dart';

@freezed
abstract class ReportEntity with _$ReportEntity {
  const factory ReportEntity({
    required String eventId,
    required ReportType type,
    String? targetEventId,
    required String targetPubkey,
    required String content,
    required DateTime created,
  }) = _ReportEntity;
}
