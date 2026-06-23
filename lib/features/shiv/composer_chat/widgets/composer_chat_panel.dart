import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/shiv/composer_chat/cubit/composer_chat_state.dart';

/// The inline chat surface shown INSIDE the composer (above the text field)
/// while it is in Manas-chat mode: a header with the scope + exit, the Q&A
/// turns, and the in-flight streamed answer.
class ComposerChatPanel extends StatelessWidget {
  const ComposerChatPanel({
    super.key,
    required this.state,
    required this.onExit,
    required this.onStop,
  });

  final ComposerChatState state;
  final VoidCallback onExit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scopeLabel = state.manasName == null
        ? 'all notes'
        : '"${state.manasName}"';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shiv · grounded in $scopeLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onExit,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.primary),
              ),
            ],
          ),
          if (state.turns.isNotEmpty || state.streaming != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in state.turns) ...[
                      _Bubble(text: t.question, isUser: true),
                      if (t.answer.isNotEmpty)
                        _Bubble(text: t.answer, isUser: false),
                    ],
                    if (state.streaming != null)
                      _Bubble(
                        text: state.streaming!.isEmpty ? '…' : state.streaming!,
                        isUser: false,
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (state.status == ComposerChatStatus.noModel)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No AI model is active. Download one from the Shiv tab.',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
          if (state.status == ComposerChatStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.errorMessage ?? 'Something went wrong.',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          if (state.status == ComposerChatStatus.streaming)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: const Text('Stop'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: isUser ? AppColors.primary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}
