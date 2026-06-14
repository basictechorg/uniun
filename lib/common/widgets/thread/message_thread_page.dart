import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/common/widgets/thread/thread_conversation_body.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// The single thread screen used by every surface (feed, channel, private
/// channel, DM): app bar + [ThreadConversationBody] + a [ComposerHost].
///
/// Data-source agnostic: callers pass the already-resolved
/// [root]/[parentNotes]/[mentionedNotes]/[replies] plus the two actions that
/// differ per surface — [onSendReply] and [onOpenThread].
class MessageThreadPage extends StatelessWidget {
  const MessageThreadPage({
    super.key,
    required this.root,
    required this.profiles,
    required this.replies,
    required this.onSendReply,
    required this.onOpenThread,
    this.parentNotes = const [],
    this.mentionedNotes = const [],
    this.replyCount,
    this.isSending = false,
    this.appBar,
    this.title,
  });

  final NoteEntity root;
  final Map<String, ProfileEntity> profiles;
  final List<NoteEntity> parentNotes;
  final List<NoteEntity> mentionedNotes;
  final List<NoteEntity> replies;
  final int? replyCount;
  final bool isSending;

  /// Custom app bar. When null, a default back + [title] bar is shown.
  final PreferredSizeWidget? appBar;
  final String? title;

  /// Posts a reply with the user-picked [mentionRefs] and any uploaded media
  /// [attachments]. The caller links it back to [root] (NIP-10 marker or
  /// reference, per surface).
  final void Function(
    String content,
    List<String> mentionRefs,
    List<MediaBlobEntity> attachments,
  ) onSendReply;

  /// Opens [noteId] as its own thread (nested navigation).
  final void Function(String noteId) onOpenThread;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: appBar ?? _defaultAppBar(context, title),
      body: ThreadConversationBody(
        root: root,
        profiles: profiles,
        parentNotes: parentNotes,
        mentionedNotes: mentionedNotes,
        replies: replies,
        replyCount: replyCount,
        onOpenThread: onOpenThread,
      ),
      bottomNavigationBar: ComposerHost(
        hintText: AppLocalizations.of(context)!.threadReplyToThis,
        isSending: isSending,
        onSend: onSendReply,
      ),
    );
  }

  PreferredSizeWidget _defaultAppBar(BuildContext context, String? title) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title ?? AppLocalizations.of(context)!.threadTitle,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}
