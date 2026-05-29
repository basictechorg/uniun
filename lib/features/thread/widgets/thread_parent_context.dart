import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/note_card/reference_note_card.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';

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
          // Sibling mode: only the last VISIBLE row connects down to root
          // (unless collapsed — then the "Show more" button bridges).
          final showConnector = widget.isSiblingGroup
              ? (isLast && !collapse)
              : true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Stack(
              children: [
                if (showConnector)
                  Positioned(
                    left: 18,
                    top: 40,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color:
                            AppColors.outlineVariant.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ReferenceNoteCard(
                  note: visible[i],
                  profile: widget.profiles[visible[i].authorPubkey],
                  onTap: () => widget.onNoteTap(visible[i].id),
                ),
              ],
            ),
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

