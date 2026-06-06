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

/// Self-contained note card. Owns its author profile, saved flag, and follow
/// flag via an internal [NoteCardCubit] (follow state is watched reactively
/// from Isar). Callers only pass the note and a tap handler.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  final NoteEntity note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NoteCardCubit>(param1: note),
      child: _NoteCardView(note: note, onTap: onTap),
    );
  }
}

class _NoteCardView extends StatelessWidget {
  const _NoteCardView({
    required this.note,
    required this.onTap,
  });

  final NoteEntity note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NoteCardCubit>();
    final cardState = cubit.state;
    final profile = cardState.profile;

    final isFollowed = cardState.isFollowed;

    final displayName = profile?.name ??
        profile?.username ??
        _shortName(note.authorPubkey);

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
            // ── Avatar ──────────────────────────────────────────────────
            UserAvatar(
              seed: note.authorPubkey,
              photoUrl: profile?.avatarUrl,
              size: 40,
              borderRadius: 20,
              onTap: () => openUserProfile(
                context,
                note.authorPubkey,
                hintName: displayName,
              ),
            ),
            const SizedBox(width: 12),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatTimeAgo(note.created),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.outline,
                              ),
                            ),
                            if (note.sourceLabel != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                note.sourcePrivateGroupId != null
                                    ? Icons.lock_outline
                                    : Icons.tag_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  note.sourceLabel!,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Note content (text) + an optional shared-note embed
                  // when this note quotes another (NIP-18).
                  if (note.content.isNotEmpty)
                    Text(
                      note.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                        height: 1.55,
                      ),
                    ),
                  if (note.quoteEventId != null) ...[
                    if (note.content.isNotEmpty) const SizedBox(height: 8),
                    EmbeddedNoteCard(eventId: note.quoteEventId!),
                  ],

                  // Hashtag chips
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
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Action row ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reply count
                        _ActionChip(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '${note.cachedReplyCount}',
                          color: AppColors.onSurfaceVariant,
                          onTap: onTap,
                        ),

                        // Reference count — outgoing refs from the edge table
                        _ActionChip(
                          icon: Icons.link_rounded,
                          label: '${note.referenceCount}',
                          color: AppColors.onSurfaceVariant,
                          onTap: onTap,
                        ),

                        // Save toggle — owned by the cubit
                        _ActionChip(
                          icon: cardState.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: cardState.isSaved
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          onTap: () => cubit.toggleSave(),
                        ),

                        // Follow / Following — owned by the cubit
                        _ActionChip(
                          icon: isFollowed
                              ? Icons.notifications
                              : Icons.notifications_none,
                          color: isFollowed
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          onTap: () => cubit.toggleFollow(),
                        ),
                        _ActionChip(
                          icon: Icons.share_outlined,
                          color: AppColors.onSurfaceVariant,
                          onTap: () =>
                              ShareSheetPage.show(context, note.id),
                        )
                      ],
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
