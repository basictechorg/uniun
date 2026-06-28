import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/markdown/note_markdown_body.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/common/widgets/note_card/embedded_note_card.dart';
import 'package:uniun/common/widgets/note_card/media_attachment_view.dart';
import 'package:uniun/common/widgets/open_user_profile.dart';
import 'package:uniun/common/widgets/note_card/note_card_menu.dart';
import 'package:uniun/common/widgets/note_card/save_toggle.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/features/share/pages/share_sheet_page.dart';

/// Larger, container-styled variant of [NoteCard] — used as the focused/root
/// note in a thread. Self-contained: owns profile, saved, and follow via an
/// internal [NoteCardCubit] (follow state is watched reactively from Isar).
/// Callers only pass the note (and optionally an explicit reply count).
///
/// Set [showActions] to `false` to hide the ⋮ menu, divider, and action chips.
/// Useful for unpublished preview cards (e.g. Nataraj) where there is no real
/// event id to act on.
class LargeNoteCard extends StatelessWidget {
  const LargeNoteCard({
    super.key,
    required this.note,
    this.replyCount,
    this.showActions = true,
    this.contained = true,
  });

  final NoteEntity note;

  /// Optional override — the thread root shows the actual loaded reply count
  /// rather than the entity's cached edge-table count.
  final int? replyCount;

  /// When false, the ⋮ menu, divider, and action-chip row are omitted.
  /// Defaults to true so all existing callers are unaffected.
  final bool showActions;

  /// When false the card drops its border + soft shadow + radius and renders
  /// flat full-bleed with a single bottom hairline — used as the thread root so
  /// the thread reads as one continuous surface (no floating card). Defaults to
  /// true so all existing callers keep the contained Card look.
  final bool contained;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NoteCardCubit>(param1: note),
      child: _LargeNoteCardView(
        note: note,
        replyCount: replyCount,
        showActions: showActions,
        contained: contained,
      ),
    );
  }
}

class _LargeNoteCardView extends StatelessWidget {
  const _LargeNoteCardView({
    required this.note,
    this.replyCount,
    this.showActions = true,
    this.contained = true,
  });

  final NoteEntity note;
  final int? replyCount;
  final bool showActions;
  final bool contained;

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
      // The thread root ([contained] == false) renders flat full-bleed with a
      // single bottom hairline, so references → root → replies read as one
      // continuous surface (no floating card). A [contained] root keeps the
      // design-system Card look (radius-lg + border + soft shadow-sm). When
      // [showActions] is false the card is embedded inside another surface
      // (e.g. the Nataraj deck card), so it renders fully flat with no border
      // to avoid a card-within-a-card.
      decoration: !showActions
          ? null
          : contained
              ? BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                  // --shadow-sm: restrained, neutral elevation.
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12151A1C),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Color(0x0A151A1C),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                )
              : const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
                  ),
                ),
      padding: !showActions
          ? EdgeInsets.zero
          : contained
              ? const EdgeInsets.all(20)
              : const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: AppColors.textMuted,
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
              // ── Overflow menu (Delete / Block) ──────────────────────────
              if (showActions)
                NoteCardMenu(
                  cubit: cubit,
                  isOwnNote: cardState.isOwnNote,
                  displayName: displayName,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (note.content.isNotEmpty)
            NoteMarkdownBody(
              content: note.content,
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textBody,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (note.quotedNote != null) ...[
            if (note.content.isNotEmpty) const SizedBox(height: 10),
            EmbeddedNoteCard(note: note.quotedNote),
          ],
          if (note.hasMedia) MediaAttachmentView(note: note, compact: false),
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
          if (showActions) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(
                color: AppColors.borderSubtle,
                height: 1,
              ),
            ),
            Row(
              children: [
                _LargeActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${replyCount ?? note.cachedReplyCount}',
                  color: AppColors.onSurfaceVariant,
                  onTap: () {},
                ),
                const SizedBox(width: 28),
                _LargeActionChip(
                  icon: Icons.link_rounded,
                  label: '${note.referenceCount}',
                  color: note.referenceCount > 0
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  onTap: () {},
                ),
                // Save hidden on own notes (kept forever already; saving is
                // for others' notes).
                if (!cardState.isOwnNote) ...[
                  const SizedBox(width: 28),
                  _LargeActionChip(
                    icon: cardState.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: cardState.isSaved
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                    onTap: () => handleSaveToggle(context, cubit),
                  ),
                ],
                const SizedBox(width: 28),
                _LargeActionChip(
                  icon: isFollowed
                      ? Icons.visibility
                      : Icons.visibility_outlined,
                  color: isFollowed
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  onTap: () => cubit.toggleFollow(),
                ),
                const Spacer(),
                _LargeActionChip(
                  icon: Icons.ios_share_rounded,
                  color: AppColors.onSurfaceVariant,
                  onTap: () => ShareSheetPage.show(context, note.id),
                ),
              ],
            ),
          ],
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
