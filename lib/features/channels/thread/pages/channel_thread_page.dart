import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_event.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_state.dart';
import 'package:uniun/features/channels/feed/widgets/channel_reference_picker.dart';
import 'package:uniun/features/channels/thread/bloc/channel_thread_bloc.dart';
import 'package:uniun/features/channels/thread/bloc/channel_thread_event.dart';
import 'package:uniun/features/channels/thread/bloc/channel_thread_state.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/followed_notes/cubit/followed_notes_cubit.dart';
import 'package:uniun/features/thread/widgets/thread_parent_context.dart';
import 'package:uniun/features/thread/widgets/thread_reply_composer.dart';
import 'package:uniun/features/thread/widgets/thread_reply_item.dart';
import 'package:uniun/features/thread/widgets/thread_root_note_card.dart';

class ChannelThreadPage extends StatelessWidget {
  const ChannelThreadPage({
    super.key,
    required this.channelId,
    required this.messageId,
    required this.channelName,
    required this.parentBloc,
  });

  final String channelId;
  final String messageId;
  final String channelName;
  final ChannelFeedBloc parentBloc;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ChannelThreadBloc()..add(LoadChannelThreadEvent(messageId)),
        ),
        BlocProvider(
          create: (_) => getIt<FollowedNotesCubit>()..load(),
        ),
        BlocProvider.value(value: parentBloc),
      ],
      child: _ChannelThreadView(
        channelId: channelId,
        messageId: messageId,
        channelName: channelName,
      ),
    );
  }
}

class _ChannelThreadView extends StatefulWidget {
  const _ChannelThreadView({
    required this.channelId,
    required this.messageId,
    required this.channelName,
  });

  final String channelId;
  final String messageId;
  final String channelName;

  @override
  State<_ChannelThreadView> createState() => _ChannelThreadViewState();
}

class _ChannelThreadViewState extends State<_ChannelThreadView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _userAvatarUrl;
  String? _userPubkey;
  String? _replyToEventId;
  String? _replyToName;
  bool _hasText = false;
  final List<ChannelMessageEntity> _mentionRefs = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final r = await getIt<GetActiveUserProfileUseCase>().call();
    if (!mounted) return;
    setState(() {
      _userPubkey = r.fold((_) => null, (p) => p.pubkeyHex);
      _userAvatarUrl = r.fold((_) => null, (p) => p.avatarUrl);
    });
  }

  void _setReplyTarget(String id, String name) {
    setState(() {
      _replyToEventId = id;
      _replyToName = name;
    });
    _focusNode.requestFocus();
  }

  void _send(BuildContext ctx) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final replyId = _replyToEventId ?? widget.messageId;
    final refs = _mentionRefs.map((m) => m.id).toList();
    _controller.clear();
    setState(() {
      _replyToEventId = null;
      _replyToName = null;
      _mentionRefs.clear();
    });
    ctx.read<ChannelFeedBloc>().add(SendChannelMessageEvent(
      channelId: widget.channelId,
      content: text,
      replyToEventId: replyId,
      mentionRefs: refs,
    ));
  }

  void _openLinkPicker(BuildContext ctx) {
    final messages = ctx.read<ChannelFeedBloc>().state.messages;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: ChannelReferencePicker(
          messages: messages,
          selected: List.of(_mentionRefs),
          onToggle: (msg) {
            setState(() {
              if (_mentionRefs.any((m) => m.id == msg.id)) {
                _mentionRefs.removeWhere((m) => m.id == msg.id);
              } else {
                _mentionRefs.add(msg);
              }
            });
          },
        ),
      ),
    );
  }

  void _openNestedThread(BuildContext ctx, ChannelMessageEntity msg) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => ChannelThreadPage(
          channelId: widget.channelId,
          messageId: msg.id,
          channelName: widget.channelName,
          parentBloc: ctx.read<ChannelFeedBloc>(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '#${widget.channelName}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: BlocListener<ChannelFeedBloc, ChannelFeedState>(
        listenWhen: (prev, curr) => prev.isSending && !curr.isSending,
        listener: (ctx, _) =>
            ctx.read<ChannelThreadBloc>().add(LoadChannelThreadEvent(widget.messageId)),
        child: BlocBuilder<ChannelThreadBloc, ChannelThreadState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final root = state.root;
            if (root == null) {
              return const Center(
                child: Text('Message not found.',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Direct parent (reply chain)
                      if (state.parent != null)
                        SliverPadding(
                          padding:
                              const EdgeInsets.only(top: 16, left: 20, right: 20),
                          sliver: SliverToBoxAdapter(
                            child: ThreadParentContext(
                              notes: [state.parent!.toNoteEntity()],
                              profiles: state.profiles,
                              onNoteTap: (_) =>
                                  _openNestedThread(context, state.parent!),
                            ),
                          ),
                        ),

                      // Mention refs (sibling group, shown above root)
                      if (state.mentionedMessages.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.only(
                            top: state.parent != null ? 0 : 16,
                            left: 20,
                            right: 20,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: ThreadParentContext(
                              notes: state.mentionedMessages
                                  .map((m) => m.toNoteEntity())
                                  .toList(),
                              profiles: state.profiles,
                              isSiblingGroup: true,
                              onNoteTap: (id) {
                                final msg = state.mentionedMessages
                                    .firstWhere((m) => m.id == id);
                                _openNestedThread(context, msg);
                              },
                            ),
                          ),
                        ),

                      // Root message card
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: (state.parent != null || state.mentionedMessages.isNotEmpty) ? 0 : 16,
                          left: 20,
                          right: 20,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: ThreadRootNoteCard(
                            note: root.toNoteEntity(),
                            profile: state.profiles[root.authorPubkey],
                            replyCount: state.replies.length,
                          ),
                        ),
                      ),

                      // Replies header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Text(
                            state.replies.isEmpty
                                ? 'No replies yet'
                                : '${state.replies.length} ${state.replies.length == 1 ? 'Reply' : 'Replies'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(
                        child: Divider(height: 1, thickness: 1,
                            color: Color(0xFFF1F5F9)),
                      ),

                      // Replies — ThreadReplyItem (same as thread page)
                      SliverPadding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).padding.bottom + 8,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final msg = state.replies[i];
                              final profile =
                                  state.profiles[msg.authorPubkey];
                              final name = profile?.name ??
                                  profile?.username ??
                                  msg.authorPubkey.substring(0, 8);
                              return ThreadReplyItem(
                                key: ValueKey(msg.id),
                                reply: msg.toNoteEntity(),
                                profile: profile,
                                nestedReplies: const [],
                                nestedProfiles: state.profiles,
                                allNestedReplies: const {},
                                showThreadLine: false,
                                onReplyTap: () => _setReplyTarget(msg.id, name),
                                onTap: () => _openNestedThread(ctx, msg),
                                onExpandReplies: (_) {},
                                onNestedReplyTap: (id, n) =>
                                    _setReplyTarget(id, n),
                              );
                            },
                            childCount: state.replies.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                ThreadReplyComposer(
                  controller: _controller,
                  focusNode: _focusNode,
                  avatarUrl: _userAvatarUrl,
                  pubkeySeed: _userPubkey ?? '',
                  replyingToName: _replyToName,
                  canPost: _hasText,
                  isSending: false,
                  onSend: () => _send(context),
                  onClearReply: () => setState(() {
                    _replyToEventId = null;
                    _replyToName = null;
                  }),
                  onTextChanged: (_) {},
                  onLinkTap: () => _openLinkPicker(context),
                  hasLinks: _mentionRefs.isNotEmpty,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
