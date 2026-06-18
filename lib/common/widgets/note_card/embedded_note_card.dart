import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/markdown/strip_markdown.dart';
import 'package:uniun/common/widgets/note_card/media_attachment_view.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final cardState = context.watch<NoteCardCubit>().state;
    final profile = cardState.profile;
    final name =
        profile?.name ?? profile?.username ?? _shortPubkey(note.authorPubkey);
    // Empty sig = the embedded snapshot failed signature verification at inbound
    // (see EmbeddedNoteCodec.verifyAndSanitize) — flag it as unverified.
    final unverified = note.sig.isEmpty;

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
                Stack(
                  clipBehavior: Clip.none,
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
                    if (unverified)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gpp_maybe_rounded,
                            size: 13,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
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
                if (unverified) ...[
                  const SizedBox(width: 6),
                  _UnverifiedChip(label: l10n.shareEmbedUnverified),
                ],
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
            _EmbeddedContentPreview(content: note.content),
            if (note.hasMedia) MediaAttachmentView(note: note),
          ],
        ),
      ),
    );
  }

  String _shortPubkey(String pk) =>
      pk.length <= 12 ? pk : '${pk.substring(0, 6)}…${pk.substring(pk.length - 4)}';
}

/// Preview body for an embedded quote. Strips markdown, caps at 4 lines, and
/// appends an "Open" hint when the source clearly exceeds what's shown so
/// the user knows there's more behind the tap.
class _EmbeddedContentPreview extends StatelessWidget {
  const _EmbeddedContentPreview({required this.content});
  final String content;

  static const _maxLines = 4;
  static const _overflowChars = 220;

  @override
  Widget build(BuildContext context) {
    final stripped = stripMarkdownPreview(content);
    final likelyOverflows = stripped.length > _overflowChars ||
        '\n'.allMatches(stripped).length >= _maxLines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stripped,
          maxLines: _maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B),
            height: 1.4,
          ),
        ),
        if (likelyOverflows) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.actionReadMore,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded,
                  size: 14, color: AppColors.primary),
            ],
          ),
        ],
      ],
    );
  }
}

/// Small amber pill flagging an embed whose snapshot signature did not verify.
class _UnverifiedChip extends StatelessWidget {
  const _UnverifiedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFB45309),
          ),
        ),
      );
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
