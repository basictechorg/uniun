import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Auto-delete picker for old public-note traffic (Kind 1 / Kind 42).
///
/// Sits below [StorageCard] on the settings page. Default is **off** —
/// nothing is deleted unless the user explicitly opts in. The retention
/// applies only to short-lived public traffic the user hasn't saved /
/// followed / authored; DMs and private-group messages are never
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
        return SettingsRow(
          icon: Icons.schedule_rounded,
          label: l10n.storageRetentionTitle,
          infoTooltip: l10n.storageRetentionSubtitle,
          showChevron: false,
          trailing: SettingsPickerButton(
            label: _label(l10n, state.autoDeleteOldNotesDays),
            onTap: () {
              final cubit = context.read<StorageCubit>();
              showSettingsOptionSheet<int?>(
                context: context,
                title: l10n.storageRetentionTitle,
                selected: state.autoDeleteOldNotesDays,
                options: [
                  for (final v in _options) SettingsOption(v, _label(l10n, v)),
                ],
                onSelected: cubit.setAutoDeleteOldNotesDays,
              );
            },
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
