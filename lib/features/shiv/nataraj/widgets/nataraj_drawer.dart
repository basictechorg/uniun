import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_model_drawer_section.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_scope_drawer_section.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Side drawer for the Nataraj deck. Two sections only:
///   1. AI MODEL — the active on-device model + open model selection.
///   2. MANAS — the scope list ("All notes" + each Manas) the deck draws from.
///
/// Deliberately has NO conversations or Ganas — those belong to the chat
/// drawer ([ShivHistoryDrawer]). Set as `drawer:` on the Nataraj deck Scaffold
/// (reads the ambient [NatarajBloc] for the scope list).
class NatarajDrawer extends StatelessWidget {
  const NatarajDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final top = MediaQuery.of(context).padding.top;

    return Drawer(
      width: 280,
      backgroundColor: AppColors.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 8,
              top: top + 16,
              bottom: 12,
            ),
            color: AppColors.surface,
            child: Text(
              l10n.natarajDrawerTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: const [
                NatarajModelDrawerSection(),
                SizedBox(height: 12),
                Divider(height: 1, color: AppColors.outlineVariant),
                SizedBox(height: 12),
                NatarajScopeDrawerSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
