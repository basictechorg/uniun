import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_bloc.dart';
import 'package:uniun/features/channels/feed/bloc/channel_feed_event.dart';
import 'package:uniun/features/channels/feed/widgets/channel_reference_picker.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/channel_message/channel_message_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';

class ChannelMessageComposer extends StatefulWidget {
  const ChannelMessageComposer({
    super.key,
    required this.channelId,
    this.avatarUrl,
    this.pubkeySeed = '',
    this.replyToEventId,
  });

  final String channelId;
  final String? avatarUrl;
  final String pubkeySeed;
  final String? replyToEventId;

  @override
  State<ChannelMessageComposer> createState() => _ChannelMessageComposerState();
}

class _ChannelMessageComposerState extends State<ChannelMessageComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  final List<ChannelMessageEntity> _mentionRefs = [];

  @override
  void initState() {
    super.initState();
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

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final refs = _mentionRefs.map((m) => m.id).toList();
    setState(() => _mentionRefs.clear());
    context.read<ChannelFeedBloc>().add(SendChannelMessageEvent(
      channelId: widget.channelId,
      content: text,
      replyToEventId: widget.replyToEventId,
      mentionRefs: refs,
    ));
  }

  void _openLinkPicker(
    BuildContext context,
    List<ChannelMessageEntity> messages,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        // Lift sheet above keyboard when search field is focused
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final state = context.watch<ChannelFeedBloc>().state;
    final isSending = state.isSending;
    final messages = state.messages;

    return KeyboardDismissOnTap(
      child: Container(
        color: Colors.white.withValues(alpha: 0.90),
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected mention ref chips
            if (_mentionRefs.isNotEmpty)
              Container(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _mentionRefs
                      .map(
                        (msg) => Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            msg.content.length > 30
                                ? '${msg.content.substring(0, 30)}…'
                                : msg.content,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurface,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          onDeleted: () => setState(
                            () =>
                                _mentionRefs.removeWhere((m) => m.id == msg.id),
                          ),
                          backgroundColor: AppColors.surfaceContainerHigh,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  UserAvatar(
                    seed: widget.pubkeySeed,
                    photoUrl: widget.avatarUrl,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.replyToEventId != null
                            ? 'Reply to message…'
                            : l10n.channelMessageHint,
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (messages.isNotEmpty)
                    GestureDetector(
                      onTap: () => _openLinkPicker(context, messages),
                      child: Icon(
                        Icons.link_rounded,
                        size: 22,
                        color: _mentionRefs.isNotEmpty
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  if (messages.isNotEmpty) const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: (_hasText && !isSending) ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 150),
                    child: GestureDetector(
                      onTap: (_hasText && !isSending)
                          ? () => _send(context)
                          : null,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: isSending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
