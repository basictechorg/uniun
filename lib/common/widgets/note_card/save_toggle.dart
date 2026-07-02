import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Handles a tap on a note card's bookmark (save) chip.
///
/// Saving is immediate. Unsaving first checks whether the note is part of any
/// Manas — if so, a confirmation warns that unsaving will also remove it from
/// those Manases, and on confirm the memberships are cleared before the note is
/// unsaved. Own notes have no save chip, so they never reach here.
Future<void> handleSaveToggle(BuildContext context, NoteCardCubit cubit) async {
  // Not yet saved → save straight away.
  if (!cubit.state.isSaved) {
    cubit.toggleSave();
    return;
  }
  // Unsaving: only prompt if the note actually belongs to a Manas.
  final manases = await cubit.manasesContainingNote();
  if (manases.isEmpty) {
    cubit.toggleSave();
    return;
  }
  if (!context.mounted) return;
  final confirmed = await _confirmUnsave(context, manases);
  if (confirmed != true) return;
  await cubit.unsaveWithManasRemoval([for (final m in manases) m.manasId]);
}

Future<bool?> _confirmUnsave(BuildContext context, List<ManasEntity> manases) {
  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;
  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      title: Row(
        children: [
          Icon(Icons.bookmark_remove_rounded,
              color: colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.unsaveManasDialogTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.unsaveManasDialogBody,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in manases) _ManasCard(manas: m),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: Text(l10n.unsaveManasDialogCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: Text(l10n.unsaveManasDialogConfirm),
        ),
      ],
    ),
  );
}

/// A Manas row styled like the membership-sheet card — icon tile + name + note
/// count. Read-only here (no toggle); it just shows what unsaving will evict.
class _ManasCard extends StatelessWidget {
  const _ManasCard({required this.manas});

  final ManasEntity manas;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              ManasIcons.byName(manas.iconName),
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manas.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.manasDrawerTileNoteCount(manas.noteCount),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
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
