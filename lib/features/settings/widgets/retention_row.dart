import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Auto-delete picker for old public-note traffic (Kind 1 / Kind 42).
///
/// Sits below [StorageCard] on the settings page. Default is **off** —
/// nothing is deleted unless the user explicitly opts in. The retention
/// applies only to short-lived public traffic the user hasn't saved /
/// followed / authored; DMs and private-channel messages are never
/// touched.
///
/// Change takes effect on next app launch (CleanupManager reads the
/// setting at Gateway-isolate boot; SharedPreferences isn't accessible
/// inside that isolate).
class RetentionRow extends StatelessWidget {
  const RetentionRow({super.key});

  static const _options = <int?>[null, 7, 30, 90, 180, 365];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<StorageCubit, StorageState>(
      buildWhen: (a, b) =>
          a.autoDeleteOldNotesDays != b.autoDeleteOldNotesDays,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.storageRetentionTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.storageRetentionSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int?>(
                value: state.autoDeleteOldNotesDays,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                items: [
                  for (final v in _options)
                    DropdownMenuItem<int?>(
                      value: v,
                      child: Text(_label(l10n, v)),
                    ),
                ],
                onChanged: (v) {
                  context.read<StorageCubit>().setAutoDeleteOldNotesDays(v);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _label(AppLocalizations l10n, int? days) {
    if (days == null) return l10n.storageRetentionOff;
    return l10n.storageRetentionDays(days);
  }
}
