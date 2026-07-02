import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/features/settings/cubit/settings_cubit.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';

/// Compact profile header row (UNIUNDesignSystem Settings.jsx): avatar + name +
/// npub + chevron, the whole row tapping through to Edit profile.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: settingsCardDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSettingsCardRadius),
        child: InkWell(
          onTap: () => context.pushNamed(AppRoutes.editProfile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                UserAvatar(
                  seed: state.pubkeyHex ?? state.npub ?? '',
                  photoUrl: state.avatarUrl,
                  size: 48,
                  showBorder: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName ?? l10n.profileAnonymous,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.handle ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
