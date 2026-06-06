import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Outgoing (own) DM bubble. Self-contained: owns profile, saved, and follow
/// via an internal [NoteCardCubit] (follow state is watched reactively from
/// Isar).
class DmOwnNoteCard extends StatelessWidget {
  const DmOwnNoteCard({
    super.key,
    required this.note,
    this.onTap,
  });

  final NoteEntity note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NoteCardCubit>(param1: note),
      child: _DmOwnNoteCardView(note: note, onTap: onTap),
    );
  }
}

class _DmOwnNoteCardView extends StatelessWidget {
  const _DmOwnNoteCardView({
    required this.note,
    this.onTap,
  });

  final NoteEntity note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NoteCardCubit>();
    final cardState = cubit.state;
    final profile = cardState.profile;

    final isFollowed = cardState.isFollowed;

    final displayName = profile?.name ??
        profile?.username ??
        _shortName(note.authorPubkey);

    final mentionRefs = note.eTagRefs
        .where((id) => id != note.rootEventId && id != note.replyToEventId)
        .toSet()
        .length;
    final hasParent =
        note.rootEventId != null || note.replyToEventId != null;
    final refCount = mentionRefs + (hasParent ? 1 : 0);

    const onBubble = AppColors.onPrimary;
    final onBubbleMuted = AppColors.onPrimary.withValues(alpha: 0.75);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Flexible(
              flex: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: onBubble,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTimeAgo(note.created),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: onBubbleMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: onBubble,
                        height: 1.55,
                      ),
                    ),
                    if (note.tTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: note.tTags
                            .take(3)
                            .map(
                              (t) => Text(
                                '#$t',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: onBubble,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ActionChip(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '${note.cachedReplyCount}',
                          color: onBubbleMuted,
                          onTap: onTap ?? () {},
                        ),
                        _ActionChip(
                          icon: Icons.link_rounded,
                          label: '$refCount',
                          color: onBubbleMuted,
                          onTap: onTap ?? () {},
                        ),
                        _ActionChip(
                          icon: cardState.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: onBubble,
                          onTap: () => cubit.toggleSave(),
                        ),
                        _ActionChip(
                          icon: isFollowed
                              ? Icons.notifications
                              : Icons.notifications_none,
                          color: onBubble,
                          onTap: () => cubit.toggleFollow(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            UserAvatar(
              seed: note.authorPubkey,
              photoUrl: profile?.avatarUrl,
              size: 40,
              borderRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _shortName(String pubkey) {
    if (pubkey.length <= 16) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          if (label != null) ...[
            const SizedBox(width: 5),
            Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
