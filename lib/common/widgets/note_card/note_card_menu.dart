import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Top-right overflow menu shared by [NoteCard] and [LargeNoteCard]. Holds the
/// destructive "Delete note" action (any note) and "Block user" (other
/// people's notes only). Owns its own block/delete snackbar feedback.
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
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
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
        if (value == 'block') _onBlock(context);
        if (value == 'delete') _onDelete(context);
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 8, top: 2, bottom: 2),
        child: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: AppColors.outline,
        ),
      ),
      itemBuilder: (context) => [
        _item('delete', Icons.delete_outline_rounded, l10n.noteCardDeleteNote),
        if (!isOwnNote)
          _item('block', Icons.block_rounded, l10n.noteCardBlockUser),
      ],
    );
  }

  /// Compact, uniform destructive menu row.
  PopupMenuItem<String> _item(String value, IconData icon, String label) {
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
