import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/features/thread/utils/thread_formatters.dart';

/// Renders the ancestor chain ABOVE the focused note (X/Twitter style).
/// Oldest ancestor is first; the last item connects via thread line to the
/// root note card below.
class ThreadParentContext extends StatefulWidget {
  const ThreadParentContext({
    super.key,
    required this.notes,
    required this.profiles,
    required this.onNoteTap,
    this.isSiblingGroup = false,
  });

  final List<NoteEntity> notes;
  final Map<String, ProfileEntity> profiles;
  final void Function(String noteId) onNoteTap;

  /// When true, rows are unrelated siblings (e.g. outgoing references all
  /// pointing to the same root note below). No vertical line is drawn between
  /// rows; only the last row emits a short stem to the root card. Beyond
  /// [_collapseThreshold] items, the first N are shown and the rest hidden
  /// behind a "Show more" button (X/Twitter-style).
  final bool isSiblingGroup;

  static const int _collapseThreshold = 2;

  @override
  State<ThreadParentContext> createState() => _ThreadParentContextState();
}

class _ThreadParentContextState extends State<ThreadParentContext> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes;
    if (notes.isEmpty) return const SizedBox.shrink();

    final collapse = widget.isSiblingGroup &&
        !_expanded &&
        notes.length > ThreadParentContext._collapseThreshold;
    final visible = collapse
        ? notes.take(ThreadParentContext._collapseThreshold).toList()
        : notes;
    final hiddenCount = notes.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isSiblingGroup)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 12,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.75)),
                const SizedBox(width: 4),
                Text(
                  'REFERENCES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color:
                        AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ...List.generate(visible.length, (i) {
          final isLast = i == visible.length - 1;
          return _ParentNoteRow(
            note: visible[i],
            profile: widget.profiles[visible[i].authorPubkey],
            onTap: () => widget.onNoteTap(visible[i].id),
            // Sibling mode: only the last VISIBLE row connects down to root
            // (unless collapsed — then the "Show more" button bridges).
            showConnector: widget.isSiblingGroup
                ? (isLast && !collapse)
                : true,
          );
        }),
        if (collapse)
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 4, bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _expanded = true),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    'Show $hiddenCount more '
                    '${hiddenCount == 1 ? 'reference' : 'references'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ParentNoteRow extends StatelessWidget {
  const _ParentNoteRow({
    required this.note,
    required this.profile,
    required this.onTap,
    required this.showConnector,
  });

  final NoteEntity note;
  final ProfileEntity? profile;
  final VoidCallback onTap;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.name ??
        profile?.username ??
        threadShortPubkey(note.authorPubkey);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + thread line column
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  UserAvatar(
                    seed: note.authorPubkey,
                    photoUrl: profile?.avatarUrl,
                    size: 38,
                    borderRadius: 19,
                  ),
                  // Connector — only shown when this row connects down (chain
                  // mode: always; sibling mode: only the last row).
                  if (showConnector)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.outlineVariant.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Content — muted, no action buttons
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${threadTimeAgo(note.created)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Content — muted, capped to avoid overshadowing root note
                    Text(
                      note.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurface.withValues(alpha: 0.55),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
