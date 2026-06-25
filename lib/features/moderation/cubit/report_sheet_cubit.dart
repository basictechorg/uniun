import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';
import 'package:uniun/domain/usecases/report_usecases.dart';

part 'report_sheet_state.dart';

/// Drives [ReportSheetPage]. Owns ONLY the publish-the-Kind-1984-event step —
/// signs and broadcasts the NIP-56 report. The hide-this-note-locally and
/// optional block-this-user side effects are handled by the caller
/// ([NoteCardMenu]) using the originating [NoteCardCubit], so the card
/// instantly collapses via `NoteCardState.isRemoved` (the same path the
/// existing "Delete note" menu item uses).
///
/// Submit therefore emits `submitted` on success carrying the user's
/// `alsoBlock` choice in [ReportSheetState.alsoBlock]; the caller acts on it.
class ReportSheetCubit extends Cubit<ReportSheetState> {
  ReportSheetCubit({
    required this.targetEventId,
    required this.targetPubkey,
  }) : super(const ReportSheetState());

  /// Null when the user is reporting a profile only.
  final String? targetEventId;
  final String targetPubkey;

  void pickType(ReportType type) {
    emit(state.copyWith(type: type));
  }

  void setReason(String text) {
    emit(state.copyWith(reason: text));
  }

  void toggleAlsoBlock(bool value) {
    emit(state.copyWith(alsoBlock: value));
  }

  Future<void> submit() async {
    final type = state.type;
    if (type == null) return;
    emit(state.copyWith(status: ReportSheetStatus.submitting));
    final target = targetEventId;
    final Either<Failure, ReportEntity> result;
    if (target == null) {
      result = await getIt<ReportUserUseCase>().call(
        ReportUserInput(
          targetPubkey: targetPubkey,
          type: type,
          content: state.reason,
        ),
      );
    } else {
      result = await getIt<ReportNoteUseCase>().call(
        ReportNoteInput(
          targetEventId: target,
          targetPubkey: targetPubkey,
          type: type,
          content: state.reason,
        ),
      );
    }
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(
        status: ReportSheetStatus.error,
        errorMessage: f.toMessage(),
      )),
      (_) => emit(state.copyWith(status: ReportSheetStatus.submitted)),
    );
  }
}
