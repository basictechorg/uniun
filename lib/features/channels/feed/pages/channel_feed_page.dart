import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_event.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_state.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/core/router/app_routes.dart';
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
  bool _didScrollToBottom = false;
  final Set<String> _everVisible = <String>{};

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

  /// Reaching the bottom of the list marks every message in the channel read.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 8) {
      context
          .read<ChannelFeedBloc>()
          .add(MarkAllChannelSeenEvent(widget.channelId));
    }
  }

  /// Marks a message seen once it has been majority-visible then leaves view.
  void _onMessageVisibility(String eventId, VisibilityInfo info) {
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
      // Silent refresh — no loading spinner, scroll position preserved.
      // listenWhen fires only if new messages arrived, scrolling to bottom
      // only when there is genuinely new content to show.
      if (mounted) bloc.add(LoadChannelFeedEvent(widget.channelId, silent: true));
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
      listenWhen: (prev, curr) => prev.messages.length != curr.messages.length,
      listener: (context, state) {
        if (!_didScrollToBottom && state.status == ChannelFeedStatus.loaded) {
          _didScrollToBottom = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        } else if (state.messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }
      },
      builder: (context, state) {
        final channelName = state.channel?.name ?? '';

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context),
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
                onSend: (text, refs) =>
                    context.read<ChannelFeedBloc>().add(SendChannelMessageEvent(
                          channelId: widget.channelId,
                          content: text,
                          mentionRefs: refs,
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

    return Builder(
      builder: (ctx) {
        return ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          itemCount: state.messages.length,
          itemBuilder: (context, i) {
            final msg = state.messages[i];

            return VisibilityDetector(
              key: ValueKey('chan-${msg.id}'),
              onVisibilityChanged: (info) => _onMessageVisibility(msg.id, info),
              child: NoteCard(
                key: ValueKey(msg.id),
                note: msg,
                onTap: () => _openThread(ctx, msg, channelName),
              ),
            );
          },
        );
      },
    );
  }
}
