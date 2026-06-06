import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/open_user_profile.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/formatters.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';
import 'package:uniun/domain/repositories/profile_repository.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Compact preview of a note embedded inside another note (a "share").
///
/// Resolves [eventId] against the local `Note` collection via
/// [NoteResolverRepository]. If the note is encrypted (DM / private channel)
/// and the viewer is not a member, the lookup misses and a "Note not
/// available" placeholder is rendered — that single behaviour gives us the
/// per-surface visibility rules for free.
class EmbeddedNoteCard extends StatefulWidget {
  const EmbeddedNoteCard({super.key, required this.eventId});

  final String eventId;

  @override
  State<EmbeddedNoteCard> createState() => _EmbeddedNoteCardState();
}

class _EmbeddedNoteCardState extends State<EmbeddedNoteCard> {
  late Future<_EmbedData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_EmbedData?> _load() async {
    final result =
        await getIt<NoteResolverRepository>().resolveNoteById(widget.eventId);
    final note = result.fold((_) => null, (n) => n);
    if (note == null) return null;
    final profileResult =
        await getIt<ProfileRepository>().getProfile(note.authorPubkey);
    final displayName = profileResult.fold<String?>(
      (_) => null,
      (p) => p.name ?? p.username,
    );
    final avatar = profileResult.fold<String?>((_) => null, (p) => p.avatarUrl);
    return _EmbedData(note: note, displayName: displayName, avatarUrl: avatar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<_EmbedData?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _ShellContainer(child: _placeholder(l10n.shareEmbedLoading));
        }
        final data = snap.data;
        if (data == null) {
          return _ShellContainer(child: _placeholder(l10n.shareEmbedNotFound));
        }
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.pushNamed(
            AppRoutes.thread,
            pathParameters: {'noteId': data.note.id},
          ),
          child: _ShellContainer(child: _resolved(data)),
        );
      },
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

  Widget _resolved(_EmbedData data) {
    final note = data.note;
    final name = data.displayName ?? _shortPubkey(note.authorPubkey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              seed: note.authorPubkey,
              photoUrl: data.avatarUrl,
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
    );
  }

  String _shortPubkey(String pk) =>
      pk.length <= 12 ? pk : '${pk.substring(0, 6)}…${pk.substring(pk.length - 4)}';
}

class _EmbedData {
  _EmbedData({required this.note, this.displayName, this.avatarUrl});
  final NoteEntity note;
  final String? displayName;
  final String? avatarUrl;
}

class _ShellContainer extends StatelessWidget {
  const _ShellContainer({required this.child});
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
