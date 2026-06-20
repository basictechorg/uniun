import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_event.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_state.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/router/nav_extensions.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';

class ChannelFeedPage extends StatelessWidget {
  const ChannelFeedPage({super.key, required this.channelId});
  final String channelId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ChannelFeedBloc()..add(LoadChannelFeedEvent(channelId)),
        ),
      ],
      child: _ChannelFeedView(channelId: channelId),
    );
  }
}

class _ChannelFeedView extends StatefulWidget {
  const _ChannelFeedView({required this.channelId});
  final String channelId;

  @override
  State<_ChannelFeedView> createState() => _ChannelFeedViewState();
}

class _ChannelFeedViewState extends State<_ChannelFeedView> {
  final _scrollController = ScrollController();

  /// Anchor key for the center sliver (the unread/bottom section). Slivers
  /// before it lay out upward, so prepending older messages never shifts the
  /// visible content.
  final _centerKey = const ValueKey('channel-feed-center');

  /// Distance from an edge at which the next page is requested.
  static const double _loadTrigger = 240;

  final Set<String> _everVisible = <String>{};

  /// Guards the blanket mark-all-seen so it fires once per arrival at the
  /// bottom rather than on every scroll frame.
  bool _markedAllAtBottom = false;

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
  /// are exhausted — marks the channel fully read.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final bloc = context.read<ChannelFeedBloc>();
    final state = bloc.state;

    if (pos.pixels <= pos.minScrollExtent + _loadTrigger) {
      if (state.hasMoreOlder && !state.isLoadingOlder) {
        bloc.add(LoadOlderChannelMessagesEvent(widget.channelId));
      }
    }

    if (pos.pixels >= pos.maxScrollExtent - _loadTrigger) {
      if (state.hasMoreUnread && !state.isLoadingUnread) {
        bloc.add(LoadNewerChannelMessagesEvent(widget.channelId));
        _markedAllAtBottom = false;
      } else if (!state.hasMoreUnread && !_markedAllAtBottom) {
        _markedAllAtBottom = true;
        bloc.add(MarkAllChannelSeenEvent(widget.channelId));
      }
    } else {
      _markedAllAtBottom = false;
    }
  }

  /// Over-pulling past the bottom edge re-checks the relay-synced store for
  /// unread messages that arrived after the feed opened.
  bool _onScrollNotification(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll > 0) {
      final bloc = context.read<ChannelFeedBloc>();
      if (!bloc.state.isLoadingUnread) {
        bloc.add(
          LoadNewerChannelMessagesEvent(widget.channelId, isRefresh: true),
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
      context.read<ChannelFeedBloc>().add(MarkChannelMessageSeenEvent(eventId));
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

  void _openThread(BuildContext ctx, NoteEntity msg, String channelName) {
    final bloc = ctx.read<ChannelFeedBloc>();
    ctx.pushNamed(AppRoutes.thread, pathParameters: {'noteId': msg.id}).then((_) {
      // Pull any replies posted in the thread back in as newer messages,
      // without resetting the boundary anchor or scroll position.
      if (mounted) {
        bloc.add(
          LoadNewerChannelMessagesEvent(widget.channelId, isRefresh: true),
        );
      }
    });
  }

  void _showChannelQrSheet(BuildContext context, ChannelFeedState state) {
    final channel = state.channel;
    if (channel == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => UniunQrCard.publicChannel(
        name: channel.name,
        channelId: channel.channelId,
        relays: channel.relays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<ChannelFeedBloc, ChannelFeedState>(
      // Scroll to the bottom only when the user's own sent message lands.
      listenWhen: (prev, curr) =>
          prev.isSending &&
          !curr.isSending &&
          curr.messages.length > prev.messages.length,
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
      builder: (context, state) {
        final channelName = state.channel?.name ?? '';

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: UniunBackButton(
              onPressed: () => context.popOrHome(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$channelName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                if (state.channel?.about.isNotEmpty == true)
                  Text(
                    state.channel!.about,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            actions: [
              if (state.channel != null) ...[
                IconButton(
                  onPressed: () => _showChannelQrSheet(context, state),
                  icon: const Icon(
                    Icons.qr_code_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: l10n.channelShareQrTitle,
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessageList(context, state, channelName)),
              ComposerHost(
                hintText: l10n.channelMessageHint,
                isSending: state.isSending,
                onSend: (text, refs, attachments) =>
                    context.read<ChannelFeedBloc>().add(SendChannelMessageEvent(
                          channelId: widget.channelId,
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
    ChannelFeedState state,
    String channelName,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.status == ChannelFeedStatus.error) {
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
                    channelName,
                  ),
                  childCount: top.length,
                ),
              ),
              SliverList(
                key: _centerKey,
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _messageTile(ctx, bottom[i], channelName),
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
      ],
    );
  }

  Widget _messageTile(BuildContext ctx, NoteEntity msg, String channelName) {
    return VisibilityDetector(
      key: ValueKey('chan-${msg.id}'),
      onVisibilityChanged: (info) => _onMessageVisibility(msg.id, info),
      child: NoteCard(
        key: ValueKey(msg.id),
        note: msg,
        onTap: () => _openThread(ctx, msg, channelName),
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
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}
