import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/qr/uniun_qr_button.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/common/qr/uniun_qr_scanner_page.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/note_thread_navigator.dart';
import 'package:uniun/domain/usecases/followed_note_usecases.dart';
import 'package:uniun/features/profile/pages/user_profile_page.dart';
import 'package:uniun/features/vishnu/drawer/bloc/drawer_bloc.dart' as app_drawer;
import 'package:uniun/features/vishnu/drawer/utils/drawer_search.dart';

class VishnuDrawer extends StatefulWidget {
  const VishnuDrawer({super.key});

  @override
  State<VishnuDrawer> createState() => _VishnuDrawerState();
}

class _VishnuDrawerState extends State<VishnuDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _close(BuildContext context) => Navigator.pop(context);

  // Reuses the exact per-surface navigation of the sectioned rows, switched on
  // the result's kind. Keeps the unified search list free of nav branching.
  Future<void> _onResultTap(
    BuildContext context,
    DrawerSearchResult result,
  ) async {
    switch (result.kind) {
      case DrawerSearchKind.channel:
        _close(context);
        context.pushNamed(
          AppRoutes.channelDetail,
          pathParameters: {'channelId': result.id},
        );
      case DrawerSearchKind.privateChannel:
        _close(context);
        context.pushNamed(
          AppRoutes.privateChannelDetail,
          pathParameters: {'groupId': result.id},
        );
      case DrawerSearchKind.dm:
        _close(context);
        context.pushNamed(
          AppRoutes.chatDm,
          pathParameters: {'id': result.id},
        );
      case DrawerSearchKind.followedUser:
        _close(context);
        context.pushNamed(
          AppRoutes.userProfile,
          extra: UserProfileArgs(pubkeyHex: result.id),
        );
      case DrawerSearchKind.followedNote:
        _close(context);
        getIt<ClearNewReferencesUseCase>().call(result.id);
        await openEventThread(
          context,
          result.id,
          openAsNote: () => context.pushNamed(
            AppRoutes.thread,
            pathParameters: {'noteId': result.id},
          ),
        );
        // ignore: use_build_context_synchronously
        if (context.mounted) {
          context.read<app_drawer.DrawerBloc>().add(app_drawer.DrawerLoadEvent());
        }
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.drawerComingSoon(feature)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 280,
      child: BlocBuilder<app_drawer.DrawerBloc, app_drawer.DrawerState>(
        builder: (context, state) {
          final loaded = state is app_drawer.DrawerLoaded ? state : null;
          final l10n = AppLocalizations.of(context)!;
          return Column(
            children: [
              _DrawerHeader(
                name: loaded?.userName ?? '...',
                npub: loaded?.npub ?? '',
                pubkeyHex: loaded?.pubkeyHex ?? '',
                avatarUrl: loaded?.avatarUrl,
                myRelays: loaded?.myRelays ?? const [],
              ),

              Expanded(
                child: _query.trim().isNotEmpty
                    ? _SearchResultsList(
                        results: loaded == null
                            ? const <DrawerSearchResult>[]
                            : buildDrawerSearchResults(loaded, _query),
                        onTap: (r) => _onResultTap(context, r),
                      )
                    : ListView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: [
                    // ── Main nav ──────────────────────────────────────────
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: l10n.drawerHome,
                      active: true,
                      onTap: () => _close(context),
                    ),
                    _NavItem(
                      icon: Icons.bookmark_rounded,
                      label: l10n.drawerSavedNotes,
                      onTap: () {
                        _close(context);
                        context.pushNamed(AppRoutes.savedNotes);
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Following Notes (collapsible) ─────────────────────
                    _CollapsibleSection(
                      icon: Icons.notifications_none_rounded,
                      title: l10n.drawerFollowingNotes,
                      itemCount: (loaded?.followedNotes ?? []).length,
                      emptyHint: l10n.drawerNoFollowedNotes,
                      onAdd: () => _showComingSoon(context, l10n.drawerHome),
                      children: [
                        for (final item in loaded?.followedNotes ?? [])
                          _FollowedNoteRow(
                            item: item,
                            onTap: () async {
                              _close(context);
                              getIt<ClearNewReferencesUseCase>()
                                  .call(item.eventId);
                              await openEventThread(
                                context,
                                item.eventId,
                                openAsNote: () => context.pushNamed(
                                  AppRoutes.thread,
                                  pathParameters: {'noteId': item.eventId},
                                ),
                              );
                              // ignore: use_build_context_synchronously
                              if (context.mounted) {
                                context.read<app_drawer.DrawerBloc>().add(
                                    app_drawer.DrawerLoadEvent());
                              }
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Following Users (collapsible) ─────────────────────
                    _CollapsibleSection(
                      icon: Icons.person_outline_rounded,
                      title: l10n.drawerFollowingSectionTitle,
                      itemCount: (loaded?.followedUsers ?? []).length,
                      emptyHint: l10n.drawerFollowingEmpty,
                      onAdd: () {
                        _close(context);
                        context.pushNamed(
                          AppRoutes.scanQr,
                          extra: UniunQrScanIntent.follow,
                        );
                      },
                      children: [
                        for (final user in loaded?.followedUsers ?? [])
                          _FollowedUserRow(
                            user: user,
                            onTap: () {
                              _close(context);
                              context.pushNamed(
                                AppRoutes.userProfile,
                                extra: UserProfileArgs(pubkeyHex: user.pubkey),
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Channels (collapsible) ────────────────────────────
                    _CollapsibleSection(
                      icon: Icons.tag_rounded,
                      title: l10n.drawerChannels,
                      itemCount: (loaded?.channels ?? []).length,
                      emptyHint: l10n.drawerNoChannels,
                      onAdd: () {
                        _close(context);
                        context.pushNamed(AppRoutes.channelEntry);
                      },
                      children: [
                        for (final ch in loaded?.channels ?? [])
                          _ChannelRow(
                            channel: ch,
                            onTap: () {
                              _close(context);
                              context.pushNamed(
                                AppRoutes.channelDetail,
                                pathParameters: {'channelId': ch.id},
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Private Channels (collapsible) ────────────────────
                    _CollapsibleSection(
                      icon: Icons.lock_outline_rounded,
                      title: l10n.drawerPrivateChannels,
                      itemCount: (loaded?.privateChannels ?? []).length,
                      emptyHint: l10n.drawerNoPrivateChannels,
                      onAdd: () {
                        _close(context);
                        context.pushNamed(AppRoutes.privateChannelEntry);
                      },
                      children: [
                        for (final ch in loaded?.privateChannels ?? [])
                          _PrivateChannelRow(
                            channel: ch,
                            onTap: () {
                              _close(context);
                              context.pushNamed(
                                AppRoutes.privateChannelDetail,
                                pathParameters: {'groupId': ch.id},
                              );
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Direct Messages (collapsible) ─────────────────────
                    _CollapsibleSection(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.drawerDirectMessages,
                      itemCount: (loaded?.dms ?? []).length,
                      emptyHint: l10n.drawerNoMessages,
                      onAdd: () {
                        _close(context);
                        context.pushNamed(AppRoutes.createDm);
                      },
                      children: [
                        for (final dm in loaded?.dms ?? [])
                          _DmRow(
                            dm: dm,
                            onTap: () {
                              _close(context);
                              context.pushNamed(
                                AppRoutes.chatDm,
                                pathParameters: {'id': dm.pubkey},
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              _DrawerSearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onClear: () => setState(() {
                  _searchController.clear();
                  _query = '';
                }),
              ),

              _DrawerFooter(
                onSettings: () {
                  _close(context);
                  context.pushNamed(AppRoutes.settings);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.npub,
    required this.pubkeyHex,
    required this.myRelays,
    this.avatarUrl,
  });

  final String name;
  final String npub;
  final String pubkeyHex;
  final String? avatarUrl;
  final List<String> myRelays;

  void _showQr(BuildContext context) {
    if (npub.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          UniunQrCard.user(npub: npub, name: name, relays: myRelays),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 16, 8, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(
                seed: pubkeyHex,
                photoUrl: avatarUrl,
                size: 40,
                borderRadius: 10,
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF22C55E),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          UniunQrScanButton(
            onTap: () => context.pushNamed(AppRoutes.scanQr),
            tooltip: 'Scan QR',
          ),
          UniunQrButton(
            onTap: () => _showQr(context),
            tooltip: 'My QR',
          ),
        ],
      ),
    );
  }
}

// ── Collapsible section ────────────────────────────────────────────────────────
//
// One reusable section header + expandable body. Collapse default rule: a list
// with more than 3 items starts collapsed; 3 or fewer start expanded. Once the
// user taps the header their choice wins (and survives async item reloads,
// because the user toggle is preferred over the count-derived default).

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.itemCount,
    required this.emptyHint,
    required this.children,
    this.onAdd,
  });

  final IconData icon;
  final String title;
  final int itemCount;
  final String emptyHint;
  final List<Widget> children;
  final VoidCallback? onAdd;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  bool? _userExpanded;
  late final AnimationController _controller;
  late final Animation<double> _sizeFactor;

  bool get _expanded => _userExpanded ?? widget.itemCount <= 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: _expanded ? 1 : 0,
    );
    _sizeFactor =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  // itemCount can change after an async reload; if the user hasn't toggled, the
  // count-derived default may flip, so re-sync the controller to it.
  @override
  void didUpdateWidget(covariant _CollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final target = _expanded ? 1.0 : 0.0;
    if (_controller.value == target) return;
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _toggle() {
    setState(() => _userExpanded = !_expanded);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(widget.icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (widget.onAdd != null)
                  GestureDetector(
                    onTap: widget.onAdd,
                    child: const Icon(Icons.add_rounded,
                        size: 18, color: AppColors.outline),
                  ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.outline),
                ),
              ],
            ),
          ),
        ),
        // Vertical accordion — clip height only. AnimatedCrossFade animated both
        // axes, which made rows appear to grow horizontally from center.
        SizeTransition(
          alignment: Alignment.topCenter,
          sizeFactor: _sizeFactor,
          child: Column(
            children: [
              const SizedBox(height: 4),
              if (widget.itemCount == 0)
                _EmptyHint(widget.emptyHint)
              else
                ...widget.children,
            ],
          ),
        ),

      ],
    );
  }
}

// ── Nav item ───────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Followed note row ──────────────────────────────────────────────────────────

class _FollowedNoteRow extends StatelessWidget {
  const _FollowedNoteRow({required this.item, required this.onTap});
  final app_drawer.DrawerFollowedNoteItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 16, color: AppColors.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.contentPreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (item.newReferenceCount > 0)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Followed user row ──────────────────────────────────────────────────────────

class _FollowedUserRow extends StatelessWidget {
  const _FollowedUserRow({required this.user, required this.onTap});
  final app_drawer.DrawerFollowedUserItem user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            UserAvatar(seed: user.pubkey, photoUrl: user.avatarUrl, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private channel row ────────────────────────────────────────────────────────

class _PrivateChannelRow extends StatelessWidget {
  const _PrivateChannelRow({required this.channel, required this.onTap});
  final app_drawer.DrawerPrivateChannelItem channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      channel.hasUnread ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (channel.hasUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Channel row ────────────────────────────────────────────────────────────────

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, required this.onTap});
  final app_drawer.DrawerChannelItem channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.tag_rounded, size: 18, color: AppColors.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      channel.hasUnread ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (channel.hasUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── DM row ─────────────────────────────────────────────────────────────────────

class _DmRow extends StatelessWidget {
  const _DmRow({required this.dm, required this.onTap});
  final app_drawer.DrawerDmItem dm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            UserAvatar(seed: dm.pubkey, photoUrl: dm.avatarUrl, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dm.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      dm.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (dm.unreadCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${dm.unreadCount}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Search field ───────────────────────────────────────────────────────────────
//
// Pinned at the bottom of the drawer, above the Settings footer. While it holds
// text the body above swaps to a unified result list (_SearchResultsList).

class _DrawerSearchField extends StatelessWidget {
  const _DrawerSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppColors.onSurface),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.drawerSearchHint,
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.outline),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.outline),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: controller.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.outline),
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(AppColors.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

// ── Search results ─────────────────────────────────────────────────────────────
//
// Flat, mixed list of matches across every drawer surface. Each row carries a
// leading type icon so intermixed kinds stay identifiable at a glance.

IconData _searchIconFor(DrawerSearchKind kind) {
  switch (kind) {
    case DrawerSearchKind.channel:
      return Icons.tag_rounded;
    case DrawerSearchKind.privateChannel:
      return Icons.lock_outline_rounded;
    case DrawerSearchKind.dm:
      return Icons.chat_bubble_outline_rounded;
    case DrawerSearchKind.followedNote:
      return Icons.notifications_none_rounded;
    case DrawerSearchKind.followedUser:
      return Icons.person_outline_rounded;
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.results, required this.onTap});

  final List<DrawerSearchResult> results;
  final void Function(DrawerSearchResult result) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          l10n.drawerSearchNoResults,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.outlineVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: results.length,
      itemBuilder: (_, i) => _SearchResultRow(
        result: results[i],
        onTap: () => onTap(results[i]),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final DrawerSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(_searchIconFor(result.kind),
                size: 18, color: AppColors.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      result.hasUnread ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (result.hasUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Empty hint ─────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.outlineVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────────────────

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onSettings,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                const Icon(Icons.settings_rounded,
                    size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.drawerSettings,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
