import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/settings/cubit/settings_cubit.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/features/settings/widgets/ai_card.dart';
import 'package:uniun/features/settings/widgets/app_version_row.dart';
import 'package:uniun/features/settings/widgets/cloud_provider_card.dart';
import 'package:uniun/features/settings/widgets/identity_card.dart';
import 'package:uniun/features/settings/widgets/language_row.dart';
import 'package:uniun/features/settings/widgets/logout_button.dart';
import 'package:uniun/features/settings/widgets/profile_card.dart';
import 'package:uniun/features/settings/widgets/section_label.dart';
import 'package:uniun/features/settings/widgets/settings_app_bar.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/features/settings/widgets/media_row.dart';
import 'package:uniun/features/settings/widgets/retention_row.dart';
import 'package:uniun/features/settings/widgets/sync_window_row.dart';
import 'package:uniun/features/settings/widgets/storage_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<SettingsCubit>()),
        BlocProvider(create: (_) => getIt<StorageCubit>()),
      ],
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: SettingsAppBar(title: AppLocalizations.of(context)!.settingsTitle),
      body: BlocListener<StorageCubit, StorageState>(
        listenWhen: (a, b) =>
            a.deleteSuccess != b.deleteSuccess ||
            a.deleteChatHistorySuccess != b.deleteChatHistorySuccess ||
            a.deleteError != b.deleteError,
        listener: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);
          if (state.deleteSuccess) {
            messenger.showSnackBar(SnackBar(
              content: Text(l10n.storageDeleteSuccess(state.deletedCount)),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ));
          }
          if (state.deleteChatHistorySuccess) {
            messenger.showSnackBar(SnackBar(
              content: Text(l10n.storageDeleteChatHistorySuccess),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ));
          }
          if (state.deleteError != null) {
            messenger.showSnackBar(SnackBar(
              content: Text(state.deleteError!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            if (state.isLoading) {
            return const Center(
              child: DropLoadingIndicator(color: AppColors.primary),
            );
          }
          final l10n = AppLocalizations.of(context)!;
          return ListView(
            padding: const EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: 48,
            ),
            children: [
              // ── Profile header (tap → edit profile) ───────────────────────
              ProfileCard(state: state),

              const SizedBox(height: 24),

              // ── Account ───────────────────────────────────────────────────
              SettingsSectionLabel(l10n.settingsAccount),
              const SizedBox(height: 10),
              IdentityCard(state: state),

              const SizedBox(height: 24),

              // ── Language ──────────────────────────────────────────────────
              SettingsSectionLabel(l10n.settingsLanguage),
              const SizedBox(height: 10),
              const SettingsGroup(children: [LanguageRow()]),

              const SizedBox(height: 24),

              // ── AI · Shiv (on-device model + cloud provider) ──────────────
              SettingsSectionLabel(l10n.settingsAiShiv),
              const SizedBox(height: 10),
              const SettingsGroup(
                children: [AICard(), CloudProviderCard()],
              ),

              const SizedBox(height: 24),

              // ── Storage ───────────────────────────────────────────────────
              SettingsSectionLabel(l10n.settingsStorage),
              const SizedBox(height: 10),
              const SettingsGroup(
                children: [
                  MediaRow(),
                  RetentionRow(),
                  SyncWindowRow(),
                  StorageMetricsRow(),
                  RemoveDataRow(),
                ],
              ),

              const SizedBox(height: 24),

              // ── About ─────────────────────────────────────────────────────
              SettingsSectionLabel(l10n.settingsAbout),
              const SizedBox(height: 10),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.identityPrivacyPolicy,
                    onTap: () => context.pushNamed(AppRoutes.privacyPolicy),
                  ),
                  const AppVersionRow(),
                ],
              ),

              const SizedBox(height: 28),

              // ── Log out ───────────────────────────────────────────────────
              const LogoutButton(),
            ],
          );
          },
        ),
      ),
    );
  }
}
