import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// A lightweight reference shown as a chip above the composer text.
/// [id] is the referenced event id; [label] is a human preview of it.
class ComposerReference {
  const ComposerReference({required this.id, required this.label});

  final String id;
  final String label;
}

/// Shared chat-style composer used across the app (thread replies, channel
/// thread replies, Brahma note creation).
///
/// Layout, top to bottom inside a single rounded card:
///   • optional "replying to" pill
///   • optional row of reference chips (shown like an attachment preview)
///   • the text field
///   • a control row: [avatar] [add-reference] … [draft] [send]
///
/// The avatar slot doubles as the future "switch to Shiv mode" button — pass
/// [onAvatarTap] to make it interactive.
class UniunComposer extends StatelessWidget {
  const UniunComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.avatarSeed,
    required this.onSend,
    required this.canSend,
    required this.hintText,
    this.avatarUrl,
    this.onAvatarTap,
    this.references = const [],
    this.onRemoveReference,
    this.onAddReference,
    this.replyingToName,
    this.onClearReply,
    this.onDraft,
    this.draftLabel,
    this.onTextChanged,
    this.isSending = false,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 6,
    this.applyBottomInset = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String avatarSeed;
  final String? avatarUrl;
  final VoidCallback onSend;
  final bool canSend;
  final String hintText;

  /// Tap on the avatar. Reserved for the upcoming Shiv-mode toggle.
  final VoidCallback? onAvatarTap;

  /// References currently attached, rendered as chips above the text.
  final List<ComposerReference> references;
  final void Function(String id)? onRemoveReference;

  /// Opens the reference picker. When null, the add-reference button is hidden.
  final VoidCallback? onAddReference;

  /// Reply-target context pill (channel/thread replies).
  final String? replyingToName;
  final VoidCallback? onClearReply;

  /// Optional draft action (Brahma). When null, the draft button is hidden.
  final VoidCallback? onDraft;
  final String? draftLabel;

  final void Function(String)? onTextChanged;
  final bool isSending;
  final bool autofocus;

  /// Text-field height bounds. Larger [minLines] makes a taller input box.
  final int minLines;
  final int? maxLines;

  /// When docked at the bottom of a screen, pad for the keyboard / home
  /// indicator. Set false when the composer is anchored at the top.
  final bool applyBottomInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keyboard height when open, otherwise the bottom safe-area inset (home
    // indicator) so the composer never sits under the rounded screen corner.
    final bottom = !applyBottomInset
        ? 0.0
        : media.viewInsets.bottom > 0
            ? media.viewInsets.bottom
            : media.viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 10, 10 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            if (replyingToName != null) ...[
              _ReplyPill(name: replyingToName!, onClear: onClearReply),
              const SizedBox(height: 8),
            ],
            if (references.isNotEmpty) ...[
              _ReferenceRow(
                references: references,
                onRemove: onRemoveReference,
              ),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                onChanged: onTextChanged,
                minLines: minLines,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: UserAvatar(
                    seed: avatarSeed,
                    photoUrl: avatarUrl,
                    size: 34,
                    borderRadius: 17,
                  ),
                ),
                if (onAddReference != null) ...[
                  const SizedBox(width: 8),
                  _CircleButton(
                    icon: Icons.add_link_rounded,
                    onTap: onAddReference!,
                    active: references.isNotEmpty,
                  ),
                ],
                const Spacer(),
                if (onDraft != null) ...[
                  GestureDetector(
                    onTap: isSending ? null : onDraft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        draftLabel ?? 'Draft',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: canSend && !isSending ? onSend : null,
                  child: AnimatedOpacity(
                    opacity: canSend ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: isSending
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded,
                              size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? AppColors.primary : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ReplyPill extends StatelessWidget {
  const _ReplyPill({required this.name, this.onClear});

  final String name;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '@$name',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({required this.references, this.onRemove});

  final List<ComposerReference> references;
  final void Function(String id)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: references.map((r) {
        final preview = r.label.trim();
        final label = preview.length > 30
            ? '${preview.substring(0, 30)}…'
            : preview.isEmpty
                ? r.id.substring(0, r.id.length < 8 ? r.id.length : 8)
                : preview;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => onRemove!(r.id),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: AppColors.primary),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
