import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/note_card/reference_note_card.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';

/// Renders the messages a chat message references, shown above its bubble.
/// A null entry in [refs] means that referenced message isn't available
/// locally and is rendered as a muted placeholder.
class ReferencedMessages extends StatelessWidget {
  const ReferencedMessages({
    super.key,
    required this.refs,
    required this.unavailableLabel,
    this.onTapRef,
  });

  final List<NoteEntity?> refs;
  final String unavailableLabel;
  final void Function(NoteEntity note)? onTapRef;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < refs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            if (refs[i] == null)
              Row(
                children: [
                  Icon(Icons.link_off_rounded,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unavailableLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            else
              ReferenceNoteCard(
                note: refs[i]!,
                onTap: onTapRef == null ? null : () => onTapRef!(refs[i]!),
              ),
          ],
        ],
      ),
    );
  }
}
