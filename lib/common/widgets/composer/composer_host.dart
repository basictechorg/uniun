import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/snackbar.dart';
import 'package:uniun/common/widgets/composer/markdown_text_editing_controller.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
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
  });

  final String hintText;
  final bool isSending;

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
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
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
    return UniunComposer(
      controller: _controller,
      focusNode: _focusNode,
      avatarSeed: _pubkeySeed,
      avatarUrl: _avatarUrl,
      hintText: widget.hintText,
      canSend: _hasText || _attachments.isNotEmpty,
      isSending: widget.isSending,
      replyingToName: widget.replyingToName,
      replyingToPreview: widget.replyingToPreview,
      onClearReply: widget.onClearReply,
      references: _mentionRefs,
      markdownEnabled: true,
      applyBottomInset: widget.applyBottomInset,
      onRemoveReference: (id) =>
          setState(() => _mentionRefs.removeWhere((r) => r.id == id)),
      onAddReference: _openReferencePicker,
      onAttachMedia: _attachMedia,
      attachments: _attachments,
      isAttachingMedia: _isAttaching,
      onRemoveAttachment: (sha) => setState(
          () => _attachments.removeWhere((b) => b.sha256 == sha)),
      onSend: _send,
    );
  }
}
