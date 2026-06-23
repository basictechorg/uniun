import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/snackbar.dart';
import 'package:uniun/common/widgets/composer/markdown_text_editing_controller.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/shiv/composer_chat/cubit/composer_chat_cubit.dart';
import 'package:uniun/features/shiv/composer_chat/cubit/composer_chat_state.dart';
import 'package:uniun/features/shiv/composer_chat/widgets/composer_chat_panel.dart';
import 'package:uniun/features/shiv/composer_chat/widgets/manas_picker_sheet.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_model_picker_sheet.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Stateful owner for [UniunComposer]: holds the text controller, focus node,
/// the "has text" flag, picked references, attached media blobs, and loads the
/// active user's avatar. Every surface (thread, channel feed, DM, private
/// channel) plugs in just one thing — [onSend]. Reference picking and media
/// upload are self-contained here.
class ComposerHost extends StatefulWidget {
  const ComposerHost({
    super.key,
    required this.hintText,
    required this.onSend,
    this.isSending = false,
    this.applyBottomInset = true,
    this.replyingToName,
    this.replyingToPreview,
    this.onClearReply,
    this.entityContext = const [],
  });

  final String hintText;
  final bool isSending;

  /// Recent messages of the surface this composer lives in (thread / channel /
  /// DM / private channel), already flattened to short `"author: text"` lines.
  /// Fed to the Manas-chat (WS4) so Shiv can answer about THIS conversation.
  /// Empty for surfaces with no conversation context (e.g. Brahma compose).
  final List<String> entityContext;

  /// Reply context shown as a strip above the input. When [replyingToName] is
  /// null the strip is hidden. [replyingToPreview] is an optional one-line
  /// snippet of the message being replied to; [onClearReply] dismisses it.
  final String? replyingToName;
  final String? replyingToPreview;
  final VoidCallback? onClearReply;

  /// Per-surface send action: post [content] with the picked [mentionRefs]
  /// and any [attachments] already uploaded to Blossom.
  final void Function(
    String content,
    List<String> mentionRefs,
    List<MediaBlobEntity> attachments,
  ) onSend;

  final bool applyBottomInset;

  @override
  State<ComposerHost> createState() => _ComposerHostState();
}

class _ComposerHostState extends State<ComposerHost> {
  final _controller = MarkdownTextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  String? _avatarUrl;
  String _pubkeySeed = '';
  final List<ComposerReference> _mentionRefs = [];
  final List<MediaBlobEntity> _attachments = [];
  bool _isAttaching = false;

  /// Manas-chat engine (WS4). A fresh factory instance per composer, so two
  /// chat surfaces never share state. Created lazily-but-eagerly here.
  late final ComposerChatCubit _chatCubit = getIt<ComposerChatCubit>();

  /// The scope picked for the current chat — drives the avatar icon shown
  /// while chatting. Null when not in chat mode.
  ManasChatScope? _activeScope;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final result = await getIt<GetActiveUserProfileUseCase>().call();
    result.fold((_) {}, (profile) {
      if (mounted) {
        setState(() {
          _pubkeySeed = profile.pubkeyHex;
          _avatarUrl = profile.avatarUrl;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatCubit.close();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Tap the avatar → pick a Manas scope → enter (or re-scope) chat mode.
  Future<void> _openManasChatPicker() async {
    final scope = await showManasChatPicker(context);
    if (scope == null || !mounted) return;
    setState(() => _activeScope = scope);
    _chatCubit.start(
      manasIds: scope.manasIds,
      manasName: scope.name,
      entityContext: widget.entityContext,
    );
    _focusNode.requestFocus();
  }

  /// The avatar shown while chatting: the picked Manas / All-notes icon.
  Widget _chatAvatar(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    // Chat mode: route the turn to the Manas-chat engine instead of publishing.
    if (_chatCubit.state.active) {
      if (text.isEmpty) return;
      _chatCubit.send(text);
      _controller.clear();
      return;
    }
    // Allow attachment-only sends when there's no text — useful for sharing
    // a single image/file with no caption.
    if (text.isEmpty && _attachments.isEmpty) return;
    widget.onSend(
      text,
      _mentionRefs.map((r) => r.id).toList(),
      List.of(_attachments),
    );
    _controller.clear();
    setState(() {
      _mentionRefs.clear();
      _attachments.clear();
    });
  }

  Future<void> _openReferencePicker() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.push<List<ComposerReference>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReferencePickerPage(
          title: l10n.composerReferenceTitle,
          searchHint: l10n.composerReferenceSearchHint,
          emptyLabel: l10n.composerReferenceEmpty,
          selectedLabel: l10n.composerReferenceSelected,
          initialSelected: List.of(_mentionRefs),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _mentionRefs
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _attachMedia() async {
    if (_isAttaching) return;
    final picked = await showMediaPickSheet(context);
    if (picked == null || !mounted) return;

    setState(() => _isAttaching = true);
    final messenger = ScaffoldMessenger.of(context);
    final res = await getIt<UploadMediaUseCase>().call(UploadMediaInput(
      bytes: picked.bytes,
      mime: picked.mime,
      filename: picked.filename,
      width: picked.width,
      height: picked.height,
    ));
    if (!mounted) return;
    res.fold(
      (f) {
        AppSnackbar.errorVia(messenger, f.toMessage());
        setState(() => _isAttaching = false);
      },
      (blob) {
        setState(() {
          if (!_attachments.any((b) => b.sha256 == blob.sha256)) {
            _attachments.add(blob);
          }
          _isAttaching = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComposerChatCubit, ComposerChatState>(
      bloc: _chatCubit,
      builder: (context, chat) {
        final inChat = chat.active;
        return UniunComposer(
          controller: _controller,
          focusNode: _focusNode,
          avatarSeed: _pubkeySeed,
          avatarUrl: _avatarUrl,
          hintText: inChat
              ? AppLocalizations.of(context)!
                  .composerAskScope(chat.manasName ?? 'Brahma')
              : widget.hintText,
          canSend: inChat
              ? (_hasText && chat.status != ComposerChatStatus.streaming)
              : (_hasText || _attachments.isNotEmpty),
          isSending:
              inChat ? chat.status == ComposerChatStatus.streaming : widget.isSending,
          onAvatarTap: _openManasChatPicker,
          avatarOverride: inChat && _activeScope != null
              ? _chatAvatar(_activeScope!.icon)
              : null,
          onPickModel: inChat ? () => showModelPickerSheet(context) : null,
          chatPanel: inChat
              ? ComposerChatPanel(
                  state: chat,
                  onExit: _chatCubit.exit,
                  onStop: _chatCubit.stop,
                )
              : null,
          // In chat mode the publish-only affordances are hidden.
          replyingToName: inChat ? null : widget.replyingToName,
          replyingToPreview: inChat ? null : widget.replyingToPreview,
          onClearReply: inChat ? null : widget.onClearReply,
          references: inChat ? const [] : _mentionRefs,
          markdownEnabled: !inChat,
          applyBottomInset: widget.applyBottomInset,
          onRemoveReference: inChat
              ? null
              : (id) =>
                  setState(() => _mentionRefs.removeWhere((r) => r.id == id)),
          onAddReference: inChat ? null : _openReferencePicker,
          onAttachMedia: inChat ? null : _attachMedia,
          attachments: inChat ? const [] : _attachments,
          isAttachingMedia: inChat ? false : _isAttaching,
          onRemoveAttachment: inChat
              ? null
              : (sha) => setState(
                  () => _attachments.removeWhere((b) => b.sha256 == sha)),
          onSend: _send,
        );
      },
    );
  }
}
