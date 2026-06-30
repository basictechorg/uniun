import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/l10n/locale_cubit.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Settings row showing the active app language (native name) and opening the
/// full [LanguageSelectionPage]. Reads the app-wide [LocaleCubit] so the value
/// updates immediately after a switch.
class LanguageRow extends StatelessWidget {
  const LanguageRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = context.watch<LocaleCubit>().activeLanguage;
    return SettingsRow(
      icon: Icons.language_rounded,
      label: l10n.settingsAppLanguage,
      value: active.nativeName,
      onTap: () => context.pushNamed(AppRoutes.selectLanguage),
    );
  }
}
