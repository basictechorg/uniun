import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/blocked_user/blocked_user_entity.dart';
import 'package:uniun/features/settings/cubit/blocked_users_cubit.dart';
import 'package:uniun/features/settings/widgets/section_label.dart';
import 'package:uniun/features/settings/widgets/settings_app_bar.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/l10n/app_localizations.dart';

class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BlockedUsersCubit()..load(),
      child: const _BlockedUsersView(),
    );
  }
}

class _BlockedUsersView extends StatelessWidget {
  const _BlockedUsersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: SettingsAppBar(title: l10n.blockedUsersTitle),
      body: BlocBuilder<BlockedUsersCubit, BlockedUsersState>(
        builder: (context, state) {
          if (state.status == BlockedUsersStatus.initial ||
              state.status == BlockedUsersStatus.loading) {
            return Center(
              child: DropLoadingIndicator(color: Theme.of(context).colorScheme.primary),
            );
          }
          if (state.status == BlockedUsersStatus.error) {
            return Center(
              child: Text(
                state.errorMessage ?? '',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }
          if (state.users.isEmpty) {
            return const _EmptyState();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Explainer — reinforces that blocking never deletes notes.
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 18),
                child: Text(
                  l10n.blockedUsersDescription,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SettingsSectionLabel(
                l10n.blockedUsersSectionCount(state.users.length),
              ),
              const SizedBox(height: 10),
              SettingsGroup(
                children: [
                  for (final user in state.users) _BlockedUserRow(user: user),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BlockedUserRow extends StatelessWidget {
  const _BlockedUserRow({required this.user});

  final BlockedUserEntity user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            seed: user.pubkeyHex,
            size: 42,
            borderRadius: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatShortPubkey(user.pubkeyHex),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  () {
                    final ago = formatTimeAgo(user.blockedAt);
                    // formatTimeAgo returns bare tokens ("now", "5m", "2h"…);
                    // "now" would read "Blocked now ago", so special-case it.
                    return ago == 'now'
                        ? l10n.blockedUsersBlockedJustNow
                        : l10n.blockedUsersBlockedAgo(ago);
                  }(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _UnblockButton(
            onTap: () =>
                context.read<BlockedUsersCubit>().unblock(user.pubkeyHex),
          ),
        ],
      ),
    );
  }
}

/// Compact secondary "Unblock" pill — the mock's `Button variant="secondary"
/// size="sm"`. Muted fill + neutral text so the destructive-sounding label
/// never competes with the single primary accent.
class _UnblockButton extends StatelessWidget {
  const _UnblockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            l10n.actionUnblock,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_rounded,
                size: 28,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.blockedUsersEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.blockedUsersEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
