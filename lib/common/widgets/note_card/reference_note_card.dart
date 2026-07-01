import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/markdown/strip_markdown.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_custom_colors.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

/// Muted, action-less note card used to surface a referenced/parent note.
/// Same avatar-left structure as [NoteCard] but with smaller fonts, faded
/// content, and no action chips. Content is capped to 3 lines.
class ReferenceNoteCard extends StatelessWidget {
  const ReferenceNoteCard({
    super.key,
    required this.note,
    this.profile,
    this.onTap,
  });

  final NoteEntity note;
  final ProfileEntity? profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.name ??
        profile?.username ??
        formatShortPubkey(note.authorPubkey);
    final colorScheme = Theme.of(context).colorScheme;
    final custom = context.custom;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            seed: note.authorPubkey,
            photoUrl: profile?.avatarUrl,
            size: 38,
            borderRadius: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${formatTimeAgo(note.created)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: custom.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stripMarkdownPreview(note.content),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
