import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/features/moderation/widgets/report_type_labels.dart';
import 'package:uniun/l10n/app_localizations_en.dart';

/// Covers: reportTypeLabel / reportTypeDescription — every ReportType value
/// maps to a non-empty, distinct localized string, proving the switch is
/// exhaustive and none of the branches were left pointing at the wrong key.
void main() {
  final l10n = AppLocalizationsEn();

  test('reportTypeLabel returns a non-empty label for every report type',
      () {
    for (final type in ReportType.values) {
      expect(reportTypeLabel(l10n, type), isNotEmpty);
    }
  });

  test('reportTypeDescription returns a non-empty description for every '
      'report type', () {
    for (final type in ReportType.values) {
      expect(reportTypeDescription(l10n, type), isNotEmpty);
    }
  });

  test('every report type has a distinct label (no copy-paste key mixups)',
      () {
    final labels = ReportType.values.map((t) => reportTypeLabel(l10n, t)).toSet();

    expect(labels, hasLength(ReportType.values.length));
  });

  test('every report type has a distinct description', () {
    final descriptions =
        ReportType.values.map((t) => reportTypeDescription(l10n, t)).toSet();

    expect(descriptions, hasLength(ReportType.values.length));
  });
}
