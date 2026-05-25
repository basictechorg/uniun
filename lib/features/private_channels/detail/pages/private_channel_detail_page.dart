import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/private_channels/detail/bloc/private_channel_detail_bloc.dart';
import 'package:uniun/domain/entities/private_channel_message_entity.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/core/router/app_routes.dart';

class PrivateChannelDetailPage extends StatelessWidget {
  final String groupId;
  const PrivateChannelDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PrivateChannelDetailBloc>(param1: groupId),
      child: const _PrivateChannelDetailView(),
    );
  }
}

class _PrivateChannelDetailView extends StatefulWidget {
  const _PrivateChannelDetailView();

  @override
  State<_PrivateChannelDetailView> createState() => _PrivateChannelDetailViewState();
}

class _PrivateChannelDetailViewState extends State<_PrivateChannelDetailView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  String? _myPubkeyHex;

  @override
  void initState() {
    super.initState();
    _resolveActiveUser();
  }

  Future<void> _resolveActiveUser() async {
    final res = await getIt<GetActiveUserUseCase>().call();
    if (mounted) {
      setState(() {
        _myPubkeyHex = res.fold((_) => null, (u) => u.pubkeyHex);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSend() {
    if (_textController.text.trim().isEmpty) return;
    context.read<PrivateChannelDetailBloc>().add(
      SendPrivateChannelMessageEvent(_textController.text),
    );
    _textController.clear();
  }

  void _showJoinRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) {
        return BlocProvider.value(
          value: context.read<PrivateChannelDetailBloc>(),
          child: BlocBuilder<PrivateChannelDetailBloc, PrivateChannelDetailState>(
            builder: (ctx, state) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Pending Join Requests",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (state.joinRequests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text("No pending requests."),
                      ),
                    ...state.joinRequests.map((req) {
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text("Pubkey: ${req.senderPubkey.substring(0, 8)}..."),
                        subtitle: const Text("Wants to join"),
                        trailing: ElevatedButton(
                          onPressed: state.isApproving
                              ? null
                              : () {
                            ctx.read<PrivateChannelDetailBloc>().add(
                                  ApproveJoinRequestEvent(req.keyPackageB64),
                                );
                            Navigator.pop(ctx);
                          },
                          child: state.isApproving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Approve"),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PrivateChannelDetailBloc, PrivateChannelDetailState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state.isLeft) {
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        }
      },
      builder: (context, state) {
        final title = state.channel?.name ?? "Private Channel";
        final requestsCount = state.joinRequests.length;

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            title: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.outline),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            actions: [
              if (state.isAdmin)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.group_add_rounded),
                      onPressed: () => _showJoinRequests(context),
                    ),
                    if (requestsCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$requestsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'share') {
                    Clipboard.setData(ClipboardData(text: state.groupId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Group ID copied to clipboard")),
                    );
                  } else if (val == 'leave') {
                    context.read<PrivateChannelDetailBloc>().add(LeavePrivateChannelEvent());
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Text('Copy Group ID'),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('Leave Channel', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: state.isLoading && state.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: false, // oldest at top, newest at bottom
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          // The query returns descending by timestamp if defined
                          final msg = state.messages[index];
                          final isMe =
                              _myPubkeyHex != null &&
                              msg.senderPubkey == _myPubkeyHex;
                          return _ChatBubble(message: msg, isMe: isMe);
                        },
                      ),
              ),
              _ChatInputArea(
                controller: _textController,
                onSend: _onSend,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final PrivateChannelMessageEntity message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderPubkey.substring(0, 8),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              message.decryptedContent,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? AppColors.onPrimary : AppColors.onSurface,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInputArea({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.onPrimary),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
