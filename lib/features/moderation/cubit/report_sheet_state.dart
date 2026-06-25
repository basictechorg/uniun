part of 'report_sheet_cubit.dart';

enum ReportSheetStatus { editing, submitting, submitted, error }

class ReportSheetState {
  const ReportSheetState({
    this.type,
    this.reason = '',
    this.alsoBlock = false,
    this.status = ReportSheetStatus.editing,
    this.errorMessage,
  });

  final ReportType? type;
  final String reason;

  /// When true, submit also runs `BlockUserUseCase` against the author. The
  /// reporter's hide-this-note action runs regardless — block is the heavier
  /// "never see anything from this pubkey again" toggle.
  final bool alsoBlock;

  final ReportSheetStatus status;
  final String? errorMessage;

  bool get canSubmit =>
      type != null && status != ReportSheetStatus.submitting;

  ReportSheetState copyWith({
    ReportType? type,
    String? reason,
    bool? alsoBlock,
    ReportSheetStatus? status,
    String? errorMessage,
  }) {
    return ReportSheetState(
      type: type ?? this.type,
      reason: reason ?? this.reason,
      alsoBlock: alsoBlock ?? this.alsoBlock,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}
