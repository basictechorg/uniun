import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/dm/chat/bloc/dm_chat_bloc.dart';
import 'package:uniun/domain/entities/dm/dm_message_entity.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

class DmChatPage extends StatelessWidget {
  const DmChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final otherPubkey = ModalRoute.of(context)!.settings.arguments as String;

    return BlocProvider(
      create: (_) =>
          getIt<DmChatBloc>()..add(DmChatLoadEvent(otherPubkey: otherPubkey)),
      child: const _DmChatView(),
    );
  }
}

class _DmChatView extends StatefulWidget {
  const _DmChatView();

  @override
  State<_DmChatView> createState() => _DmChatViewState();
}

class _DmChatViewState extends State<_DmChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  // To identify if message is ours
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
    context.read<DmChatBloc>().add(
      DmChatSendEvent(content: _textController.text),
    );
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DmChatBloc, DmChatState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final shortKey =
            state.otherPubkey != null && state.otherPubkey!.length > 12
            ? '${state.otherPubkey!.substring(0, 12)}...'
            : state.otherPubkey ?? 'Chat';

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.1),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  radius: 16,
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  shortKey,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  context.read<DmChatBloc>().add(DmChatRefreshEvent());
                },
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
                        reverse: true, // show latest at bottom
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          final isMe =
                              _myPubkeyHex != null &&
                              msg.receiverPubkey != _myPubkeyHex;
                          return _ChatBubble(message: msg, isMe: isMe);
                        },
                      ),
              ),
              _ChatInputArea(
                controller: _textController,
                isSending: state.isSending,
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
  final DmMessageEntity message;
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
        child: Text(
          message.content,
          style: TextStyle(
            fontSize: 15,
            color: isMe ? AppColors.onPrimary : AppColors.onSurface,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInputArea({
    required this.controller,
    required this.isSending,
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
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.onPrimary),
              onPressed: isSending ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
