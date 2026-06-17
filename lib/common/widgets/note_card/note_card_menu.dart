import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/manas/widgets/manas_membership_sheet.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Top-right overflow menu shared by [NoteCard] and [LargeNoteCard].
///
/// Items (rendered top-down):
///   • "Add to Manas" (only when the note is already saved) — opens the
///     membership sheet for this note. Manas membership is saved-only;
///     this entry is hidden when the note isn't saved so the user is
///     nudged to tap the bookmark first.
///   • Destructive "Delete note" (always) + "Block user" (when the note
///     isn't authored by the active user).
class NoteCardMenu extends StatelessWidget {
  const NoteCardMenu({
    super.key,
    required this.cubit,
    required this.isOwnNote,
    required this.displayName,
  });

  final NoteCardCubit cubit;
  final bool isOwnNote;
  final String displayName;

  Future<void> _onBlock(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await cubit.blockUser();
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(
          content: Text(failure.toMessage()),
          backgroundColor: AppColors.error,
        ),
      ),
      (_) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.blockUserSnackbar(displayName))),
      ),
    );
  }

  Future<void> _onDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await cubit.deleteNote();
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(
          content: Text(failure.toMessage()),
          backgroundColor: AppColors.error,
        ),
      ),
      (_) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.deleteNoteSnackbar)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Read isSaved reactively — the bookmark chip and this menu both write to
    // the same cubit, so the menu must rebuild when save state flips.
    return BlocBuilder<NoteCardCubit, NoteCardState>(
      buildWhen: (prev, curr) => prev.isSaved != curr.isSaved,
      builder: (context, cardState) {
        final canAddToManas = cardState.isSaved;
        return PopupMenuButton<String>(
          padding: const EdgeInsets.all(10),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          elevation: 8,
          color: AppColors.surface,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          menuPadding: const EdgeInsets.symmetric(vertical: 4),
          onSelected: (value) {
            if (value == 'manas') {
              ManasMembershipSheet.show(context, cubit.note.id);
            }
            if (value == 'block') _onBlock(context);
            if (value == 'delete') _onDelete(context);
          },
          child: const Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: AppColors.outline,
          ),
          itemBuilder: (context) => [
            if (canAddToManas) ...[
              _neutralItem('manas', Icons.psychology_rounded,
                  l10n.noteCardAddToManas),
              const PopupMenuDivider(),
            ],
            _destructiveItem('delete', Icons.delete_outline_rounded,
                l10n.noteCardDeleteNote),
            if (!isOwnNote)
              _destructiveItem(
                  'block', Icons.block_rounded, l10n.noteCardBlockUser),
          ],
        );
      },
    );
  }

  /// Non-destructive row (primary-coloured) — used for "Add to Manas".
  PopupMenuItem<String> _neutralItem(
      String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact, uniform destructive menu row.
  PopupMenuItem<String> _destructiveItem(
      String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.error),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
