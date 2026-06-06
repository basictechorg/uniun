import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/common/widgets/note_card/embedded_note_card.dart';
import 'package:uniun/common/widgets/open_user_profile.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/features/share/pages/share_sheet_page.dart';

/// Larger, container-styled variant of [NoteCard] — used as the focused/root
/// note in a thread. Self-contained: owns profile, saved, and follow via an
/// internal [NoteCardCubit] (follow state is watched reactively from Isar).
/// Callers only pass the note (and optionally an explicit reply count).
class LargeNoteCard extends StatelessWidget {
  const LargeNoteCard({
    super.key,
    required this.note,
    this.replyCount,
  });

  final NoteEntity note;

  /// Optional override — the thread root shows the actual loaded reply count
  /// rather than the entity's cached edge-table count.
  final int? replyCount;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NoteCardCubit>(param1: note),
      child: _LargeNoteCardView(note: note, replyCount: replyCount),
    );
  }
}

class _LargeNoteCardView extends StatelessWidget {
  const _LargeNoteCardView({required this.note, this.replyCount});

  final NoteEntity note;
  final int? replyCount;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NoteCardCubit>();
    final cardState = cubit.state;
    final profile = cardState.profile;

    final isFollowed = cardState.isFollowed;

    final displayName = profile?.name ??
        profile?.username ??
        formatShortPubkey(note.authorPubkey);
    final handle = profile?.username != null
        ? '@${profile!.username}'
        : '@${formatShortPubkey(note.authorPubkey)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                seed: note.authorPubkey,
                photoUrl: profile?.avatarUrl,
                size: 48,
                borderRadius: 24,
                onTap: () => openUserProfile(
                  context,
                  note.authorPubkey,
                  hintName: displayName,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          formatTimeAgo(note.created),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      handle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (note.content.isNotEmpty)
            Text(
              note.content,
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.onSurface,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (note.quoteEventId != null) ...[
            if (note.content.isNotEmpty) const SizedBox(height: 10),
            EmbeddedNoteCard(eventId: note.quoteEventId!),
          ],
          if (note.tTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: note.tTags
                  .take(5)
                  .map((t) => Text(
                        '#$t',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ))
                  .toList(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: AppColors.outlineVariant.withValues(alpha: 0.15),
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LargeActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${replyCount ?? note.cachedReplyCount}',
                  color: AppColors.onSurfaceVariant,
                  onTap: () {},
                ),
                _LargeActionChip(
                  icon: Icons.link_rounded,
                  label: '${note.referenceCount}',
                  color: AppColors.onSurfaceVariant,
                  onTap: () {},
                ),
                _LargeActionChip(
                  icon: cardState.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: cardState.isSaved
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  onTap: () => cubit.toggleSave(),
                ),
                _LargeActionChip(
                  icon: isFollowed
                      ? Icons.notifications
                      : Icons.notifications_none,
                  color: isFollowed
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  onTap: () => cubit.toggleFollow(),
                ),
                _LargeActionChip(
                  // Share — opens the share sheet for this note.
                  icon: Icons.share_outlined,
                  color: AppColors.onSurfaceVariant,
                  onTap: () => ShareSheetPage.show(context, note.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeActionChip extends StatelessWidget {
  const _LargeActionChip({
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
          Icon(icon, size: 22, color: color),
          if (label != null) ...[
            const SizedBox(width: 5),
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
    );
  }
}
