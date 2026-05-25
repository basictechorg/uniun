import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';

class ThreadReplyComposer extends StatelessWidget {
  const ThreadReplyComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.canPost,
    this.avatarUrl,
    this.pubkeySeed = '',
    this.replyingToName,
    this.isSending = false,
    this.onClearReply,
    this.onTextChanged,
    this.onLinkTap,
    this.hasLinks = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool canPost;
  final String? avatarUrl;
  final String pubkeySeed;
  final String? replyingToName;
  final bool isSending;
  final VoidCallback? onClearReply;
  final void Function(String)? onTextChanged;
  final VoidCallback? onLinkTap;
  final bool hasLinks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return KeyboardDismissOnTap(
      child: Container(
        color: Colors.white.withValues(alpha: 0.90),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyingToName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.threadReplyingTo(replyingToName!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onClearReply,
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    seed: pubkeySeed,
                    photoUrl: avatarUrl,
                    size: 32,
                    borderRadius: 16,
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: replyingToName != null
                            ? l10n.threadReplyTo(replyingToName!)
                            : l10n.threadReplyToThis,
                        hintStyle: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: onTextChanged,
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),

                  if (onLinkTap != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onLinkTap,
                      child: Icon(Icons.link_rounded,
                          size: 22,
                          color: hasLinks
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 10),

                  GestureDetector(
                    onTap: canPost ? onSend : null,
                    child: AnimatedOpacity(
                      opacity: canPost ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: isSending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                l10n.threadPost,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
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
