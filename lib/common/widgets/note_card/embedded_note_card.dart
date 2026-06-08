import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/cubit/note_card_cubit.dart';
import 'package:uniun/common/widgets/open_user_profile.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Embedded preview of a NIP-18 quoted note. `note == null` → placeholder.
class EmbeddedNoteCard extends StatelessWidget {
  const EmbeddedNoteCard({super.key, required this.note});

  final NoteEntity? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final n = note;
    if (n == null) {
      return _Shell(child: _placeholder(l10n.shareEmbedNotFound));
    }
    return BlocProvider(
      create: (_) => getIt<NoteCardCubit>(param1: n),
      child: _EmbeddedNoteView(note: n),
    );
  }

  Widget _placeholder(String text) => Row(
        children: [
          const Icon(Icons.link_off_rounded,
              size: 16, color: AppColors.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
}

class _EmbeddedNoteView extends StatelessWidget {
  const _EmbeddedNoteView({required this.note});
  final NoteEntity note;

  @override
  Widget build(BuildContext context) {
    final cardState = context.watch<NoteCardCubit>().state;
    final profile = cardState.profile;
    final name =
        profile?.name ?? profile?.username ?? _shortPubkey(note.authorPubkey);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.pushNamed(
        AppRoutes.thread,
        pathParameters: {'noteId': note.id},
      ),
      child: _Shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  seed: note.authorPubkey,
                  photoUrl: profile?.avatarUrl,
                  size: 24,
                  borderRadius: 12,
                  onTap: () => openUserProfile(
                    context,
                    note.authorPubkey,
                    hintName: name,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatTimeAgo(note.created),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              note.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortPubkey(String pk) =>
      pk.length <= 12 ? pk : '${pk.substring(0, 6)}…${pk.substring(pk.length - 4)}';
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}
