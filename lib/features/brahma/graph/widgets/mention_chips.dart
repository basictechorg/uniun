import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Horizontal wrap of chips showing the currently selected mention references.
class MentionChips extends StatelessWidget {
  const MentionChips({
    super.key,
    required this.mentions,
    required this.onRemove,
  });

  final List<NoteEntity> mentions;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: mentions.map((n) {
          final preview = n.content.trim();
          final label = preview.length > 30
              ? '${preview.substring(0, 30)}…'
              : preview.isEmpty
                  ? n.id.substring(0, 8)
                  : preview;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => onRemove(n.id),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: AppColors.primary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
