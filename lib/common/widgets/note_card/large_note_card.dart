import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/saved_note_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/followed_notes/cubit/followed_notes_cubit.dart';

/// Larger, container-styled variant of [NoteCard] — used as the focused/root
/// note in a thread. Wires save + follow state internally via the cubit and
/// use cases so callers only need to pass the note + profile + reply count.
class LargeNoteCard extends StatefulWidget {
  const LargeNoteCard({
    super.key,
    required this.note,
    this.profile,
    this.replyCount,
  });

  final NoteEntity note;
  final ProfileEntity? profile;
  final int? replyCount;

  @override
  State<LargeNoteCard> createState() => _LargeNoteCardState();
}

class _LargeNoteCardState extends State<LargeNoteCard> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    getIt<IsSavedNoteUseCase>()
        .call(widget.note.id)
        .then((r) => r.fold((_) {}, (v) {
              if (mounted) setState(() => _isSaved = v);
            }));
  }

  @override
  Widget build(BuildContext context) {
    final followedState = context.watch<FollowedNotesCubit>().state;
    final isFollowed =
        followedState.notes.any((n) => n.eventId == widget.note.id);

    final profile = widget.profile;
    final displayName = profile?.name ??
        profile?.username ??
        formatShortPubkey(widget.note.authorPubkey);
    final handle = profile?.username != null
        ? '@${profile!.username}'
        : '@${formatShortPubkey(widget.note.authorPubkey)}';

    final mentionRefs = widget.note.eTagRefs
        .where((id) =>
            id != widget.note.rootEventId && id != widget.note.replyToEventId)
        .toSet()
        .length;
    final hasParent = widget.note.rootEventId != null ||
        widget.note.replyToEventId != null;
    final refCount = mentionRefs + (hasParent ? 1 : 0);

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
                seed: widget.note.authorPubkey,
                photoUrl: profile?.avatarUrl,
                size: 48,
                borderRadius: 24,
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
                          formatTimeAgo(widget.note.created),
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
          Text(
            widget.note.content,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.onSurface,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (widget.note.tTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.note.tTags
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
                  label: '${widget.replyCount ?? 0}',
                  color: AppColors.onSurfaceVariant,
                  onTap: () {},
                ),
                _LargeActionChip(
                  icon: Icons.link_rounded,
                  label: '$refCount',
                  color: AppColors.onSurfaceVariant,
                  onTap: () {},
                ),
                _LargeActionChip(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _isSaved
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  onTap: () async {
                    final nowSaved = !_isSaved;
                    setState(() => _isSaved = nowSaved);
                    if (nowSaved) {
                      final result =
                          await getIt<SaveNoteUseCase>().call(widget.note);
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
                      final result = await getIt<UnsaveNoteUseCase>()
                          .call(widget.note.id);
                      result.fold(
                        (_) {
                          if (mounted) setState(() => _isSaved = true);
                        },
                        (_) {},
                      );
                    }
                  },
                ),
                _LargeActionChip(
                  icon: isFollowed
                      ? Icons.notifications
                      : Icons.notifications_none,
                  color: isFollowed
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  onTap: () {
                    final cubit = context.read<FollowedNotesCubit>();
                    if (isFollowed) {
                      cubit.unfollowNote(widget.note.id);
                    } else {
                      cubit.followNote(
                        widget.note.id,
                        formatContentPreview(widget.note.content),
                      );
                    }
                  },
                ),
                _LargeActionChip(
                  icon: Icons.share_outlined,
                  color: AppColors.onSurfaceVariant,
                  onTap: () {}, // TODO: implement share sheet
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
