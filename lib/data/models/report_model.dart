import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';

part 'report_model.g.dart';

/// One NIP-56 (Kind 1984) report the active identity has filed. Stored locally
/// so the UI can hide already-reported items and surface a "My Reports" list.
/// The corresponding signed event is also enqueued in [EventQueueModel] for
/// relay broadcast.
@Collection(ignore: {'copyWith'})
@Name('Report')
class ReportModel {
  Id id = Isar.autoIncrement;

  /// SHA-256 hex of the published Kind-1984 event. Guards idempotency — the
  /// caller checks this before signing to avoid republishing identical reports.
  @Index(unique: true, replace: true)
  late String eventId;

  /// `ReportType.name`. Stored as a string rather than an enum index so the
  /// wire-level NIP-56 type value matches verbatim.
  late String reportType;

  /// Target note id when reporting a specific note; null when reporting only
  /// the user. Indexed for fast targeted lookups (e.g. v2's "have I already
  /// reported this?" gate, currently unused).
  @Index()
  String? targetEventId;

  /// Reported author's pubkey. Always present — every report carries a `p`
  /// tag per NIP-56.
  @Index()
  late String targetPubkey;

  /// Free-form reporter explanation. Empty string when omitted.
  late String content;

  @Index()
  late DateTime created;
}

extension ReportModelExtension on ReportModel {
  ReportEntity toDomain() => ReportEntity(
        eventId: eventId,
        type: ReportType.values.firstWhere(
          (t) => t.name == reportType,
          orElse: () => ReportType.other,
        ),
        targetEventId: targetEventId,
        targetPubkey: targetPubkey,
        content: content,
        created: created,
      );
}
