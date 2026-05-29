import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/channels/thread/utils/thread_formatters.dart';

// ── Top-level reply item (Twitter/X style) ────────────────────────────────────

class ThreadReplyItem extends StatefulWidget {
  const ThreadReplyItem({
    super.key,
    required this.reply,
    this.profile,
    required this.nestedReplies,
    required this.nestedProfiles,
    required this.allNestedReplies,
    required this.showThreadLine, // kept for API compat — ignored
    required this.onReplyTap,
    this.onTap, // navigate into this reply's detail
    this.onExpandReplies,
    this.onNestedReplyTap,
    this.hasUnread = false,
  });

  final NoteEntity reply;
  final ProfileEntity? profile;
  final List<NoteEntity> nestedReplies;
  final Map<String, ProfileEntity> nestedProfiles;
  final Map<String, List<NoteEntity>> allNestedReplies;
  final bool showThreadLine;
  final VoidCallback onReplyTap;
  /// Tapping the content area of this reply navigates into its detail thread.
  final VoidCallback? onTap;
  /// Called when the user expands nested replies (replaces ExpandReplyEvent).
  final void Function(String replyId)? onExpandReplies;
  /// Called when user taps reply on a nested item (replaces SetReplyTargetEvent).
  final void Function(String replyId, String replyName)? onNestedReplyTap;
  /// Show a primary-colour dot until the user opens this reply's thread.
  final bool hasUnread;

  @override
  State<ThreadReplyItem> createState() => _ThreadReplyItemState();
}

class _ThreadReplyItemState extends State<ThreadReplyItem> {
  bool _isSaved = false;
  bool _showReplies = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    getIt<IsSavedNoteUseCase>()
        .call(widget.reply.id)
        .then((r) => r.fold((_) {}, (v) {
              if (mounted) setState(() => _isSaved = v);
            }));
  }

  @override
  void didUpdateWidget(ThreadReplyItem old) {
    super.didUpdateWidget(old);
    // Auto-open when replies stream in while the user already expanded
    if (_showReplies &&
        widget.nestedReplies.length > old.nestedReplies.length) {
      setState(() {});
    }
  }

  Future<void> _toggleSave() async {
    final nowSaved = !_isSaved;
    setState(() => _isSaved = nowSaved);
    if (nowSaved) {
      final result = await getIt<SaveNoteUseCase>().call(widget.reply);
      result.fold(
        (_) {
          if (mounted) setState(() => _isSaved = false);
        },
        (saved) {
          getIt<EmbedAndStoreNoteUseCase>()
              .call((saved.eventId, saved.content));
        },
      );
    } else {
      final result = await getIt<UnsaveNoteUseCase>().call(widget.reply.id);
      result.fold(
        (_) {
          if (mounted) setState(() => _isSaved = true);
        },
        (_) {},
      );
    }
  }

  void _onToggleReplies() {
    if (!_showReplies &&
        widget.nestedReplies.isEmpty &&
        widget.reply.cachedReplyCount > 0) {
      widget.onExpandReplies?.call(widget.reply.id);
    }
    setState(() => _showReplies = !_showReplies);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final displayName = profile?.name ??
        profile?.username ??
        threadShortPubkey(widget.reply.authorPubkey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main reply card ────────────────────────────────────────────────────
        Stack(
          children: [
        GestureDetector(
          onTap: () {
            if (widget.hasUnread && !_opened) setState(() => _opened = true);
            widget.onTap?.call();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                seed: widget.reply.authorPubkey,
                photoUrl: profile?.avatarUrl,
                size: 40,
                borderRadius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name · time
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${threadTimeAgo(widget.reply.created)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Content
                    Text(
                      widget.reply.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Action row
                    Row(
                      children: [
                        _ActionBtn(
                          icon: Icons.reply_rounded,
                          onTap: widget.onReplyTap,
                        ),
                        const SizedBox(width: 20),
                        if (widget.reply.cachedReplyCount > 0)
                          _ActionBtn(
                            icon: _showReplies
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            label: '${widget.reply.cachedReplyCount}',
                            onTap: _onToggleReplies,
                            active: _showReplies,
                          ),
                        const Spacer(),
                        _ActionBtn(
                          icon: _isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          onTap: _toggleSave,
                          active: _isSaved,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ), // closes GestureDetector
            if (widget.hasUnread && !_opened)
              const Positioned(
                top: 10,
                right: 0,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ), // closes Stack

        // ── Inline sub-replies (one level max) ────────────────────────────────
        if (_showReplies) ...[
          if (widget.nestedReplies.isNotEmpty)
            ...List.generate(widget.nestedReplies.length, (i) {
              final nested = widget.nestedReplies[i];
              final nestedProfile =
                  widget.nestedProfiles[nested.authorPubkey];
              final nestedName = nestedProfile?.name ??
                  nestedProfile?.username ??
                  threadShortPubkey(nested.authorPubkey);
              return Padding(
                padding: const EdgeInsets.only(left: 52, bottom: 14),
                child: NoteCard(
                  note: nested,
                  profile: nestedProfile,
                  replyCount: nested.cachedReplyCount,
                  onTap: () {
                    widget.onNestedReplyTap?.call(nested.id, nestedName);
                  },
                ),
              );
            })
          else if (widget.reply.cachedReplyCount > 0)
            const _InlineLoadingSkeleton(),
        ],

        // ── Divider between replies ────────────────────────────────────────────
        Divider(
          height: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
        ),
      ],
    );
  }
}

// ── Shared action button ───────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Skeleton while tree loads ─────────────────────────────────────────────────

class _InlineLoadingSkeleton extends StatelessWidget {
  const _InlineLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
