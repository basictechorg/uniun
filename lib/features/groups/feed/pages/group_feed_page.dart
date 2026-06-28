import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/features/groups/feed/bloc/group_feed_bloc.dart';
import 'package:uniun/features/groups/feed/bloc/group_feed_event.dart';
import 'package:uniun/features/groups/feed/bloc/group_feed_state.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/router/nav_extensions.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/features/shiv/generation/chat_helpers.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/widgets/jump_to_bottom_button.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';

class GroupFeedPage extends StatelessWidget {
  const GroupFeedPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              GroupFeedBloc()..add(LoadGroupFeedEvent(groupId)),
        ),
      ],
      child: _GroupFeedView(groupId: groupId),
    );
  }
}

class _GroupFeedView extends StatefulWidget {
  const _GroupFeedView({required this.groupId});
  final String groupId;

  @override
  State<_GroupFeedView> createState() => _GroupFeedViewState();
}

class _GroupFeedViewState extends State<_GroupFeedView> {
  final _scrollController = ScrollController();

  /// Anchor key for the center sliver (the unread/bottom section). Slivers
  /// before it lay out upward, so prepending older messages never shifts the
  /// visible content.
  final _centerKey = const ValueKey('group-feed-center');

  /// Distance from an edge at which the next page is requested.
  static const double _loadTrigger = 240;

  final Set<String> _everVisible = <String>{};

  /// Guards the blanket mark-all-seen so it fires once per arrival at the
  /// bottom rather than on every scroll frame.
  bool _markedAllAtBottom = false;

  /// Whether the jump-to-latest button is showing (set when scrolled above the
  /// bottom).
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Drives bidirectional pagination: nearing the top loads older read
  /// messages, nearing the bottom loads newer unread messages and — once those
  /// are exhausted — marks the group fully read.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final bloc = context.read<GroupFeedBloc>();
    final state = bloc.state;

    if (pos.pixels <= pos.minScrollExtent + _loadTrigger) {
      if (state.hasMoreOlder && !state.isLoadingOlder) {
        bloc.add(LoadOlderGroupMessagesEvent(widget.groupId));
      }
    }

    if (pos.pixels >= pos.maxScrollExtent - _loadTrigger) {
      if (state.hasMoreUnread && !state.isLoadingUnread) {
        bloc.add(LoadNewerGroupMessagesEvent(widget.groupId));
        _markedAllAtBottom = false;
      } else if (!state.hasMoreUnread && !_markedAllAtBottom) {
        _markedAllAtBottom = true;
        bloc.add(MarkAllGroupSeenEvent(widget.groupId));
      }
    } else {
      _markedAllAtBottom = false;
    }

    final showJump =
        pos.maxScrollExtent - pos.pixels > kJumpToBottomTolerance;
    if (showJump != _showJumpButton) {
      setState(() => _showJumpButton = showJump);
    }
  }

  /// Jumps to the newest message and marks the whole group read.
  void _jumpToLatest() {
    _scrollToBottom();
    context.read<GroupFeedBloc>().add(MarkAllGroupSeenEvent(widget.groupId));
  }

  /// Over-pulling past the bottom edge re-checks the relay-synced store for
  /// unread messages that arrived after the feed opened.
  bool _onScrollNotification(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll > 0) {
      final bloc = context.read<GroupFeedBloc>();
      if (!bloc.state.isLoadingUnread) {
        bloc.add(
          LoadNewerGroupMessagesEvent(widget.groupId, isRefresh: true),
        );
      }
    }
    return false;
  }

  /// Marks a message seen once it has been majority-visible then leaves view.
  void _onMessageVisibility(String eventId, VisibilityInfo info) {
    // visibility_detector schedules updates on a timer, so callbacks can
    // fire after the State is unmounted (e.g. when navigating away while
    // messages are scrolling out of view). Guard with `mounted`.
    if (!mounted) return;
    if (info.visibleFraction >= 0.5) {
      _everVisible.add(eventId);
    } else if (info.visibleFraction == 0 && _everVisible.contains(eventId)) {
      context.read<GroupFeedBloc>().add(MarkGroupMessageSeenEvent(eventId));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _openThread(BuildContext ctx, NoteEntity msg, String groupName) {
    final bloc = ctx.read<GroupFeedBloc>();
    ctx.pushNamed(AppRoutes.thread, pathParameters: {'noteId': msg.id}).then((_) {
      // Pull any replies posted in the thread back in as newer messages,
      // without resetting the boundary anchor or scroll position.
      if (mounted) {
        bloc.add(
          LoadNewerGroupMessagesEvent(widget.groupId, isRefresh: true),
        );
      }
    });
  }

  void _showGroupQrSheet(BuildContext context, GroupFeedState state) {
    final group = state.group;
    if (group == null) return;
    UniunQrCard.show(
      context,
      card: UniunQrCard.publicGroup(
        name: group.name,
        groupId: group.groupId,
        relays: group.relays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<GroupFeedBloc, GroupFeedState>(
      // Scroll to the bottom only when the user's own sent message lands.
      listenWhen: (prev, curr) =>
          prev.isSending &&
          !curr.isSending &&
          curr.messages.length > prev.messages.length,
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
      builder: (context, state) {
        final groupName = state.group?.name ?? '';

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.glassFill,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 4,
            leading: UniunBackButton(
              onPressed: () => context.popOrHome(),
            ),
            // # glyph + name (no "#" prefix — the icon conveys it). About rides
            // below as a subtitle. No member count (DESIGN.md §3.5).
            title: Row(
              children: [
                const Icon(
                  Icons.tag_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (state.group?.about.isNotEmpty == true)
                        Text(
                          state.group!.about,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (state.group != null) ...[
                IconButton(
                  onPressed: () => _showGroupQrSheet(context, state),
                  icon: const Icon(
                    Icons.qr_code_rounded,
                    color: AppColors.onSurface,
                  ),
                  tooltip: l10n.groupShareQrTitle,
                ),
              ],
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
            ),
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessageList(context, state, groupName)),
              ComposerHost(
                hintText: l10n.groupMessageHint,
                isSending: state.isSending,
                entityContext: entityContextLines(state.messages),
                onSend: (text, refs, attachments) =>
                    context.read<GroupFeedBloc>().add(SendGroupMessageEvent(
                          groupId: widget.groupId,
                          content: text,
                          mentionRefs: refs,
                          attachments: attachments,
                        )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    GroupFeedState state,
    String groupName,
  ) {
    if (state.isLoading) {
      return const Center(
        child: DropLoadingIndicator(color: AppColors.primary),
      );
    }

    if (state.status == GroupFeedStatus.error) {
      return Center(
        child: Text(
          state.errorMessage ?? 'Something went wrong.',
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    if (state.messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Be the first!',
          style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
      );
    }

    // Split the loaded range at the read→unread boundary. The top section is
    // rendered in the reversed (pre-center) sliver so it grows upward; the
    // bottom section is the center sliver and grows downward.
    final top = state.messages.sublist(0, state.boundaryIndex);
    final bottom = state.messages.sublist(state.boundaryIndex);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: CustomScrollView(
            controller: _scrollController,
            center: _centerKey,
            // Boundary at mid-screen when there are unread messages; otherwise
            // anchored at the bottom like a standard chat.
            anchor: state.openedAtMiddle ? 0.5 : 1.0,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _messageTile(
                    ctx,
                    top[top.length - 1 - i],
                    groupName,
                  ),
                  childCount: top.length,
                ),
              ),
              SliverList(
                key: _centerKey,
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _messageTile(ctx, bottom[i], groupName),
                  childCount: bottom.length,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 8,
                ),
              ),
            ],
          ),
        ),
        if (state.isLoadingOlder)
          const Positioned(top: 0, left: 0, right: 0, child: _EdgeSpinner()),
        if (state.isLoadingUnread)
          const Positioned(bottom: 0, left: 0, right: 0, child: _EdgeSpinner()),
        Positioned(
          right: 16,
          bottom: 12,
          child: JumpToBottomButton(
            visible: _showJumpButton,
            onPressed: _jumpToLatest,
            tooltip: AppLocalizations.of(context)!.jumpToLatest,
          ),
        ),
      ],
    );
  }

  Widget _messageTile(BuildContext ctx, NoteEntity msg, String groupName) {
    return VisibilityDetector(
      key: ValueKey('chan-${msg.id}'),
      onVisibilityChanged: (info) => _onMessageVisibility(msg.id, info),
      child: NoteCard(
        key: ValueKey(msg.id),
        note: msg,
        onTap: () => _openThread(ctx, msg, groupName),
      ),
    );
  }
}

/// A small progress strip shown while an older/newer page is loading.
class _EdgeSpinner extends StatelessWidget {
  const _EdgeSpinner();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: DropLoadingIndicator(
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
