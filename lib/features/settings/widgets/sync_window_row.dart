import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Sync-window picker — how many days of history the capped sync surfaces
/// (feed / public-group / private-group messages) pull. Default 7.
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
        return SettingsRow(
          icon: Icons.sync_rounded,
          label: l10n.syncWindowTitle,
          infoTooltip: l10n.syncWindowSubtitle,
          showChevron: false,
          trailing: SettingsPickerButton(
            label: l10n.syncWindowDays(state.recentSyncWindowDays),
            onTap: () {
              final cubit = context.read<StorageCubit>();
              showSettingsOptionSheet<int>(
                context: context,
                title: l10n.syncWindowTitle,
                selected: state.recentSyncWindowDays,
                options: [
                  for (final v in _options)
                    SettingsOption(v, l10n.syncWindowDays(v)),
                ],
                onSelected: cubit.setRecentSyncWindowDays,
              );
            },
          ),
        );
      },
    );
  }
}
