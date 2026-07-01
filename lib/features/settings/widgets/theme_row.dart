import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme_mode.dart';
import 'package:uniun/core/theme/theme_cubit.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Settings row showing the active [AppThemeMode] and opening a bottom sheet
/// with three radios: system / light / dark. Reads the app-wide
/// [ThemeCubit] so the value updates immediately after a switch.
class ThemeRow extends StatelessWidget {
  const ThemeRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = context.watch<ThemeCubit>().state;
    return SettingsRow(
      icon: _iconFor(mode),
      label: l10n.settingsTheme,
      value: _labelFor(mode, l10n),
      onTap: () => _showThemeSheet(context),
    );
  }

  IconData _iconFor(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => Icons.brightness_auto_outlined,
        AppThemeMode.light => Icons.light_mode_outlined,
        AppThemeMode.dark => Icons.dark_mode_outlined,
      };

  String _labelFor(AppThemeMode mode, AppLocalizations l10n) => switch (mode) {
        AppThemeMode.system => l10n.settingsThemeSystem,
        AppThemeMode.light => l10n.settingsThemeLight,
        AppThemeMode.dark => l10n.settingsThemeDark,
      };
}

Future<void> _showThemeSheet(BuildContext context) async {
  final cubit = context.read<ThemeCubit>();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return BlocProvider.value(
        value: cubit,
        child: const _ThemeSheet(),
      );
    },
  );
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = context.watch<ThemeCubit>().state;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.settingsThemeSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ThemeOption(
              mode: AppThemeMode.system,
              label: l10n.settingsThemeSystem,
              icon: Icons.brightness_auto_outlined,
              active: active == AppThemeMode.system,
            ),
            _ThemeOption(
              mode: AppThemeMode.light,
              label: l10n.settingsThemeLight,
              icon: Icons.light_mode_outlined,
              active: active == AppThemeMode.light,
            ),
            _ThemeOption(
              mode: AppThemeMode.dark,
              label: l10n.settingsThemeDark,
              icon: Icons.dark_mode_outlined,
              active: active == AppThemeMode.dark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.icon,
    required this.active,
  });

  final AppThemeMode mode;
  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await context.read<ThemeCubit>().setMode(mode);
        if (context.mounted) Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Radio<AppThemeMode>(
              value: mode,
              groupValue: active ? mode : null,
              onChanged: (_) async {
                await context.read<ThemeCubit>().setMode(mode);
                if (context.mounted) Navigator.of(context).pop();
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
