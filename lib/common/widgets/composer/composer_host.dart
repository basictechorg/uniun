import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/markdown_text_editing_controller.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Stateful owner for [UniunComposer]: holds the text controller, focus node,
/// the "has text" flag, the selected references + the reference-picker flow, and
/// loads the active user's avatar. Every surface (thread, channel feed, DM,
/// private channel) plugs in just one thing — [onSend]. The reference picker is
/// self-contained ([ReferencePickerPage] queries notes itself).
class ComposerHost extends StatefulWidget {
  const ComposerHost({
    super.key,
    required this.hintText,
    required this.onSend,
    this.isSending = false,
    this.applyBottomInset = true,
  });

  final String hintText;
  final bool isSending;

  /// The only per-surface action: post [content] with the picked [mentionRefs].
  final void Function(String content, List<String> mentionRefs) onSend;

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
    if (text.isEmpty) return;
    widget.onSend(text, _mentionRefs.map((r) => r.id).toList());
    _controller.clear();
    setState(() => _mentionRefs.clear());
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

  @override
  Widget build(BuildContext context) {
    return UniunComposer(
      controller: _controller,
      focusNode: _focusNode,
      avatarSeed: _pubkeySeed,
      avatarUrl: _avatarUrl,
      hintText: widget.hintText,
      canSend: _hasText,
      isSending: widget.isSending,
      references: _mentionRefs,
      markdownEnabled: true,
      applyBottomInset: widget.applyBottomInset,
      onRemoveReference: (id) =>
          setState(() => _mentionRefs.removeWhere((r) => r.id == id)),
      onAddReference: _openReferencePicker,
      onSend: _send,
    );
  }
}
