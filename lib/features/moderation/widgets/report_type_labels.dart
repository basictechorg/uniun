import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Maps each [ReportType] to its localized display strings. Shared by every
/// surface that renders report categories so adding a type is one switch
/// update, not a hunt across widget files.

String reportTypeLabel(AppLocalizations l10n, ReportType t) {
  switch (t) {
    case ReportType.nudity:
      return l10n.reportTypeNudity;
    case ReportType.malware:
      return l10n.reportTypeMalware;
    case ReportType.profanity:
      return l10n.reportTypeProfanity;
    case ReportType.illegal:
      return l10n.reportTypeIllegal;
    case ReportType.spam:
      return l10n.reportTypeSpam;
    case ReportType.impersonation:
      return l10n.reportTypeImpersonation;
    case ReportType.other:
      return l10n.reportTypeOther;
  }
}

String reportTypeDescription(AppLocalizations l10n, ReportType t) {
  switch (t) {
    case ReportType.nudity:
      return l10n.reportTypeNudityDescription;
    case ReportType.malware:
      return l10n.reportTypeMalwareDescription;
    case ReportType.profanity:
      return l10n.reportTypeProfanityDescription;
    case ReportType.illegal:
      return l10n.reportTypeIllegalDescription;
    case ReportType.spam:
      return l10n.reportTypeSpamDescription;
    case ReportType.impersonation:
      return l10n.reportTypeImpersonationDescription;
    case ReportType.other:
      return l10n.reportTypeOtherDescription;
  }
}
