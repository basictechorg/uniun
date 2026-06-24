import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/moderation/cubit/report_sheet_cubit.dart';
import 'package:uniun/features/moderation/widgets/also_block_toggle.dart';
import 'package:uniun/features/moderation/widgets/reason_field.dart';
import 'package:uniun/features/moderation/widgets/report_type_list.dart';
import 'package:uniun/features/moderation/widgets/submit_button.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Modal bottom sheet that lets the user pick a NIP-56 report type and add an
/// optional reason. Returns `true` on successful submit, `null` on dismiss.
///
/// Caller is responsible for confirming the success snackbar — this only
/// signals the outcome via the modal's pop value.
class ReportSheetPage extends StatelessWidget {
  const ReportSheetPage._({
    required this.targetEventId,
    required this.targetPubkey,
  });

  final String? targetEventId;
  final String targetPubkey;

  static Future<bool?> show(
    BuildContext context, {
    String? targetEventId,
    required String targetPubkey,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportSheetPage._(
        targetEventId: targetEventId,
        targetPubkey: targetPubkey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportSheetCubit(
        targetEventId: targetEventId,
        targetPubkey: targetPubkey,
      ),
      child: const _ReportSheetView(),
    );
  }
}

class _ReportSheetView extends StatelessWidget {
  const _ReportSheetView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<ReportSheetCubit, ReportSheetState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == ReportSheetStatus.submitted) {
          Navigator.of(context).pop(true);
        }
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DragHandle(),
              const SizedBox(height: 16),
              Text(
                l10n.reportSheetTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const ReportTypeList(),
              const SizedBox(height: 12),
              ReasonField(hint: l10n.reportSheetReasonHint),
              const SizedBox(height: 8),
              // Outcome explainer + optional "also block" toggle. The hide
              // action is unconditional; the block adds the heavier hammer.
              Text(
                l10n.reportSheetOutcomeHint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 8),
              const AlsoBlockToggle(),
              const SizedBox(height: 12),
              const _ErrorRow(),
              const SubmitButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportSheetCubit, ReportSheetState>(
      buildWhen: (a, b) => a.errorMessage != b.errorMessage,
      builder: (context, state) {
        if (state.errorMessage == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            state.errorMessage!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 13,
            ),
          ),
        );
      },
    );
  }
}
