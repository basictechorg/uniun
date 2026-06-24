import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/moderation/cubit/report_sheet_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Primary "Submit report" button. Disabled until a [ReportType] is picked,
/// shows a spinner while the cubit's three-step submit pipeline runs.
class SubmitButton extends StatelessWidget {
  const SubmitButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ReportSheetCubit, ReportSheetState>(
      builder: (context, state) {
        return SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: state.canSubmit
                ? () => context.read<ReportSheetCubit>().submit()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.outlineVariant,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.status == ReportSheetStatus.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Text(
                    l10n.reportSheetSubmit,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
