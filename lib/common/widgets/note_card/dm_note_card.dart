import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

class DmNoteCard extends StatefulWidget {
  const DmNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.profile,
    this.replyCount = 0,
    this.isFollowed = false,
    this.isSaved = false,
    this.onFollowTap,
    this.onSaveTap,
  });

  final NoteEntity note;
  final VoidCallback? onTap;
  final ProfileEntity? profile;
  final int replyCount;
  final bool isFollowed;
  final bool isSaved;
  final VoidCallback? onFollowTap;
  final VoidCallback? onSaveTap;

  @override
  State<DmNoteCard> createState() => _DmNoteCardState();
}

class _DmNoteCardState extends State<DmNoteCard> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  @override
  void didUpdateWidget(DmNoteCard old) {
    super.didUpdateWidget(old);
    if (old.isSaved != widget.isSaved) _isSaved = widget.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final displayName = profile?.name ??
        profile?.username ??
        _shortName(widget.note.authorPubkey);

    final mentionRefs = widget.note.eTagRefs
        .where((id) =>
            id != widget.note.rootEventId && id != widget.note.replyToEventId)
        .toSet()
        .length;
    final hasParent = widget.note.rootEventId != null ||
        widget.note.replyToEventId != null;
    final refCount = mentionRefs + (hasParent ? 1 : 0);

    return InkWell(
      onTap: widget.onTap,
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
            UserAvatar(
              seed: widget.note.authorPubkey,
              photoUrl: profile?.avatarUrl,
              size: 40,
              borderRadius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              formatTimeAgo(widget.note.created),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.note.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                      height: 1.55,
                    ),
                  ),
                  if (widget.note.tTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.note.tTags
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
                  Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ActionChip(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '${widget.replyCount}',
                          color: AppColors.onSurfaceVariant,
                          onTap: widget.onTap ?? () {},
                        ),
                        _ActionChip(
                          icon: Icons.link_rounded,
                          label: '$refCount',
                          color: AppColors.onSurfaceVariant,
                          onTap: widget.onTap ?? () {},
                        ),
                        _ActionChip(
                          icon: _isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _isSaved
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          onTap: () {
                            setState(() => _isSaved = !_isSaved);
                            widget.onSaveTap?.call();
                          },
                        ),
                        _ActionChip(
                          icon: widget.isFollowed
                              ? Icons.notifications
                              : Icons.notifications_none,
                          color: widget.isFollowed
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                          onTap: widget.onFollowTap ?? () {},
                        ),
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
