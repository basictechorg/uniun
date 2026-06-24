import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/moderation/cubit/report_sheet_cubit.dart';
import 'package:uniun/features/moderation/widgets/also_block_toggle.dart';
import 'package:uniun/features/moderation/widgets/reason_field.dart';
import 'package:uniun/features/moderation/widgets/report_type_list.dart';
import 'package:uniun/features/moderation/widgets/submit_button.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// What the report sheet sends back on a successful submit. `null` from
/// [ReportSheetPage.show] means the user dismissed without submitting.
class ReportSheetResult {
  const ReportSheetResult({required this.alsoBlock});

  /// True when the user ticked "Also block this user" before submitting.
  final bool alsoBlock;
}

/// Modal bottom sheet that lets the user pick a NIP-56 report type and add an
/// optional reason. The sheet OWNS only the publish step (Kind 1984); the
/// caller layers on the local hide-this-note and optional block side effects.
///
/// Returns a [ReportSheetResult] on submit, `null` on dismiss.
class ReportSheetPage extends StatelessWidget {
  const ReportSheetPage._({
    required this.targetEventId,
    required this.targetPubkey,
  });

  final String? targetEventId;
  final String targetPubkey;

  static Future<ReportSheetResult?> show(
    BuildContext context, {
    String? targetEventId,
    required String targetPubkey,
  }) {
    // 80% of screen height — guarantees room for the status bar, keeps the
    // sheet shorter than the keyboard-less viewport, and lets the inner
    // scroll view absorb anything that doesn't fit (e.g. on small phones
    // when all 7 report types + reason field + buttons are visible at once).
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return showModalBottomSheet<ReportSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
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
          Navigator.of(context).pop(
            ReportSheetResult(alsoBlock: state.alsoBlock),
          );
        }
      },
      child: SafeArea(
        // The content scrolls when it overflows; the Submit button stays
        // pinned at the bottom so it never disappears behind the keyboard or
        // gets cut off on small phones.
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DragHandle(),
              const SizedBox(height: 12),
              Text(
                l10n.reportSheetTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ReportTypeList(),
                      const SizedBox(height: 8),
                      ReasonField(hint: l10n.reportSheetReasonHint),
                      const SizedBox(height: 6),
                      // Outcome explainer + optional "also block" toggle.
                      // Hide is unconditional; block is the heavier hammer.
                      Text(
                        l10n.reportSheetOutcomeHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AlsoBlockToggle(),
                      const _ErrorRow(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
          padding: const EdgeInsets.only(top: 8),
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
