import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Sync-window picker — how many days of history the capped sync surfaces
/// (feed / public-channel / private-channel messages) pull. Default 7.
///
/// Followed notes, DMs, and the MLS control plane always pull full history.
/// Change takes effect on next app launch (the Gateway isolate reads the
/// setting at boot; SharedPreferences isn't accessible inside that isolate).
class SyncWindowRow extends StatelessWidget {
  const SyncWindowRow({super.key});

  static const _options = <int>[7, 14, 30, 60, 90];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<StorageCubit, StorageState>(
      buildWhen: (a, b) => a.recentSyncWindowDays != b.recentSyncWindowDays,
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
                      l10n.syncWindowTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.syncWindowSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: state.recentSyncWindowDays,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                items: [
                  for (final v in _options)
                    DropdownMenuItem<int>(
                      value: v,
                      child: Text(l10n.syncWindowDays(v)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    context.read<StorageCubit>().setRecentSyncWindowDays(v);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
