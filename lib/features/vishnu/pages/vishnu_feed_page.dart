import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/floating_nav.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/vishnu/drawer/bloc/drawer_bloc.dart' as app_drawer;
import 'package:uniun/features/vishnu/drawer/widgets/vishnu_drawer.dart';
import 'package:uniun/features/vishnu/bloc/vishnu_feed_bloc.dart';
import 'package:uniun/features/vishnu/widgets/new_notes_banner.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';
import 'package:uniun/common/note_thread_navigator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VishnuFeedPage extends StatefulWidget {
  const VishnuFeedPage({
    super.key,
    required this.currentIndex,
    required this.onSwitchTab,
  });
  final int currentIndex;
  final Future<void> Function(int) onSwitchTab;

  @override
  State<VishnuFeedPage> createState() => _VishnuFeedPageState();
}

class _VishnuFeedPageState extends State<VishnuFeedPage> {
  late final app_drawer.DrawerBloc _drawerBloc;
  bool _navVisible = true;

  @override
  void initState() {
    super.initState();
    _drawerBloc = getIt<app_drawer.DrawerBloc>()
      ..add(app_drawer.DrawerLoadEvent());
  }

  @override
  void dispose() {
    _drawerBloc.close();
    super.dispose();
  }

  void _onScrollDirection(ScrollDirection direction) {
    if (direction == ScrollDirection.reverse && _navVisible) {
      setState(() => _navVisible = false);
    } else if (direction == ScrollDirection.forward && !_navVisible) {
      setState(() => _navVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<app_drawer.DrawerBloc>.value(
      value: _drawerBloc,
      child: Scaffold(
        backgroundColor: AppColors.surfaceContainerLowest,
        drawer: const VishnuDrawer(),
        onDrawerChanged: (isOpen) {
          if (isOpen) {
            _drawerBloc.add(app_drawer.DrawerLoadEvent());
          }
        },
        body: Stack(
          children: [
            _VishnuFeedView(onScrollDirection: _onScrollDirection),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _navVisible ? Offset.zero : const Offset(0, 1.5),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: FloatingNav(
                  currentIndex: widget.currentIndex,
                  onTap: widget.onSwitchTab,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed view ─────────────────────────────────────────────────────────────────

class _VishnuFeedView extends StatefulWidget {
  const _VishnuFeedView({required this.onScrollDirection});
  final void Function(ScrollDirection) onScrollDirection;

  @override
  State<_VishnuFeedView> createState() => _VishnuFeedViewState();
}

class _VishnuFeedViewState extends State<_VishnuFeedView> {
  final _scrollController = ScrollController();
  final Set<String> _everVisible = <String>{};
  bool _scrollingUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final dir = _scrollController.position.userScrollDirection;
    widget.onScrollDirection(dir);
    // The "new notes" button only surfaces while scrolling up toward the top;
    // it stays hidden while reading/scrolling down. Idle keeps the last state.
    if (dir == ScrollDirection.forward && !_scrollingUp) {
      setState(() => _scrollingUp = true);
    } else if (dir == ScrollDirection.reverse && _scrollingUp) {
      setState(() => _scrollingUp = false);
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<VishnuFeedBloc>().add(const LoadMoreFeedEvent());
    }
  }

  Future<void> _onRefresh() async {
    context.read<VishnuFeedBloc>().add(const RefreshFeedEvent());
    await context.read<VishnuFeedBloc>().stream.firstWhere(
      (s) => s.status != VishnuFeedStatus.loading,
      orElse: () => const VishnuFeedState(),
    );
  }

  Future<void> _onLoadNewNotes() async {
    context.read<VishnuFeedBloc>().add(const LoadNewNotesEvent());
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Per-note visibility callback. Marks as seen once the user has had the
  /// note majority-visible at some point AND it has now left the viewport.
  /// Debounced via [_everVisible] + bloc's [_markedThisSession] set.
  void _onNoteVisibility(String eventId, VisibilityInfo info) {
    if (info.visibleFraction >= 0.5) {
      _everVisible.add(eventId);
    } else if (info.visibleFraction == 0 && _everVisible.contains(eventId)) {
      context.read<VishnuFeedBloc>().add(MarkFeedItemSeenEvent(eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          const _FeedHeader(),

          // ── Feed list ────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<VishnuFeedBloc, VishnuFeedState>(
              builder: (context, feedState) {
                // Initial loading
                if (feedState.status == VishnuFeedStatus.loading &&
                    feedState.items.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  );
                }

                // Error with no items
                if (feedState.status == VishnuFeedStatus.error &&
                    feedState.items.isEmpty) {
                  return _ErrorView(
                    message: feedState.errorMessage ?? 'Something went wrong',
                    onRetry: () => context.read<VishnuFeedBloc>().add(
                      const FeedOpenedEvent(),
                    ),
                  );
                }

                // Empty feed
                if (feedState.items.isEmpty) {
                  return const _EmptyFeedView();
                }

                // Feed list. NoteCard self-manages profile/saved/followed.
                return Builder(
                  builder: (context) {
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _onRefresh,
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.of(context).padding.bottom + 96,
                            ),
                              itemCount: feedState.items.length +
                                  (feedState.status ==
                                          VishnuFeedStatus.loadingMore
                                      ? 1
                                      : 0),
                              itemBuilder: (context, i) {
                                if (i == feedState.items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }

                                final note = feedState.items[i];

                                return VisibilityDetector(
                                  key: ValueKey('feed-${note.id}'),
                                  onVisibilityChanged: (info) =>
                                      _onNoteVisibility(note.id, info),
                                  child: NoteCard(
                                    key: ValueKey(note.id),
                                    note: note,
                                    onTap: () => openEventThread(
                                      context,
                                      note.id,
                                      openAsNote: () => context.pushNamed(
                                        AppRoutes.thread,
                                        pathParameters: {'noteId': note.id},
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          // Floating overlay — sits above the listview with
                          // no background of its own, so it doesn't steal
                          // vertical space when there's nothing new.
                          Positioned(
                            top: 4,
                            left: 0,
                            right: 0,
                            child: Builder(
                              builder: (context) {
                                final showBanner =
                                    _scrollingUp && feedState.newCount > 0;
                                return IgnorePointer(
                                  ignoring: !showBanner,
                                  child: NewNotesBanner(
                                    count: showBanner ? feedState.newCount : 0,
                                    onTap: _onLoadNewNotes,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feed header ───────────────────────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Drawer / logo button
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/tabs/vishnu.svg',
                  height: 32,
                  width: 32,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Notifications bell
          const SizedBox(width: 4),
          // Avatar — shows logged-in user's actual profile picture
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: BlocBuilder<app_drawer.DrawerBloc, app_drawer.DrawerState>(
              builder: (context, drawerState) {
                String? avatarUrl;
                String seed = '';
                if (drawerState is app_drawer.DrawerLoaded) {
                  avatarUrl = drawerState.avatarUrl;
                  seed = drawerState.pubkeyHex;
                }
                return UserAvatar(
                  seed: seed,
                  photoUrl: avatarUrl,
                  size: 32,
                  borderRadius: 10,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyFeedView extends StatelessWidget {
  const _EmptyFeedView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_add_outlined,
              size: 52,
              color: AppColors.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.vishnuFeedEmptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.vishnuFeedEmptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.scanQr),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(l10n.vishnuFeedEmptyCta),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.actionRetry),
          ),
        ],
      ),
    );
  }
}
