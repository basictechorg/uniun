import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/moderation/cubit/report_sheet_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Optional checkbox row on the report sheet. When ticked, Submit also runs
/// `BlockUserUseCase` against the reported author. The reporter's hide-this-
/// note action runs regardless — block is the heavier "never see anything
/// from this pubkey again" toggle.
class AlsoBlockToggle extends StatelessWidget {
  const AlsoBlockToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ReportSheetCubit, ReportSheetState>(
      buildWhen: (a, b) => a.alsoBlock != b.alsoBlock,
      builder: (context, state) {
        return InkWell(
          onTap: () => context
              .read<ReportSheetCubit>()
              .toggleAlsoBlock(!state.alsoBlock),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  state.alsoBlock
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 22,
                  color: state.alsoBlock
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.reportSheetAlsoBlock,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
