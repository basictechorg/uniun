import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';
import 'package:uniun/domain/usecases/blocked_user_usecases.dart';
import 'package:uniun/domain/usecases/deleted_note_usecases.dart';
import 'package:uniun/domain/usecases/report_usecases.dart';

part 'report_sheet_state.dart';

/// Drives [ReportSheetPage]. Submit composes three orthogonal effects:
///   1. ALWAYS publish the NIP-56 Kind-1984 event (`ReportNoteUseCase` /
///      `ReportUserUseCase`).
///   2. ALWAYS hide the reported note locally for this user via the existing
///      tombstone system (`DeleteNoteUseCase`) — so a reported note never
///      keeps showing up in this user's feed / threads. The author is NOT
///      affected; this is purely a local view-state change. Skipped when the
///      sheet was opened on a profile rather than a specific note.
///   3. OPTIONALLY block the author (`BlockUserUseCase`) when the user ticks
///      "Also block this user" on the sheet — drops every future event from
///      this pubkey at the gateway.
///
/// On the first step's failure the sheet stays open and surfaces the error;
/// 2/3 are best-effort follow-ups and do not roll back step 1.
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
    final ok = await result.fold(
      (f) async {
        emit(state.copyWith(
          status: ReportSheetStatus.error,
          errorMessage: f.toMessage(),
        ));
        return false;
      },
      (_) async => true,
    );
    if (!ok) return;

    // Step 2 — hide the offending note locally so the reporter never sees it
    // again (silent on profile-only reports).
    if (target != null) {
      await getIt<DeleteNoteUseCase>().call(target);
    }
    // Step 3 — optional permanent block of the author.
    if (state.alsoBlock) {
      await getIt<BlockUserUseCase>().call(targetPubkey);
    }
    if (isClosed) return;
    emit(state.copyWith(status: ReportSheetStatus.submitted));
  }
}
