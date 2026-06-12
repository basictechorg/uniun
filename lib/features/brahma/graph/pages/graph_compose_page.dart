import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/features/brahma/graph/widgets/compose_header.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/markdown_text_editing_controller.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/media/widgets/media_picker_sheet.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Compose page opened from the graph FAB or draft edit button.
class GraphComposePage extends StatelessWidget {
  const GraphComposePage({
    super.key,
    this.initialDraftId,
    this.autoPublish = false,
  });

  final String? initialDraftId;

  /// When true the draft is published automatically once pre-filled.
  /// Used by the graph panel's "Publish" button — currently unused since
  /// publish is now fired directly from the panel.
  final bool autoPublish;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BrahmaCreateBloc>(
      create: (_) => getIt<BrahmaCreateBloc>()..add(const LoadDraftsEvent()),
      child: _GraphComposeView(
        initialDraftId: initialDraftId,
        autoPublish: autoPublish,
      ),
    );
  }
}

// ── View ────────────────────────────────────────────────────────────────────────

/// Strip above the composer showing attached media chips + an
/// "Attach from library" button. v1 only supports picking from existing
/// blobs; upload-from-phone arrives separately.
class _MediaAttachStrip extends StatelessWidget {
  const _MediaAttachStrip({required this.state});
  final BrahmaCreateState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () async {
              final blob = await MediaPickerSheet.show(context);
              if (blob == null) return;
              if (!context.mounted) return;
              context
                  .read<BrahmaCreateBloc>()
                  .add(AttachExistingMediaEvent(blob));
            },
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: Text(l10n.composerAttachLibrary),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          const Spacer(),
          if (state.attachedMedia.isNotEmpty)
            Text(
              '${state.attachedMedia.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          for (final b in state.attachedMedia)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InputChip(
                avatar: const Icon(Icons.image_outlined, size: 14),
                label: Text(
                  b.sha256.substring(0, 6),
                  style: const TextStyle(fontSize: 11),
                ),
                onDeleted: () => context
                    .read<BrahmaCreateBloc>()
                    .add(RemoveAttachedMediaEvent(b.sha256)),
              ),
            ),
        ],
      ),
    );
  }
}

class _GraphComposeView extends StatefulWidget {
  const _GraphComposeView({this.initialDraftId, this.autoPublish = false});
  final String? initialDraftId;
  final bool autoPublish;

  @override
  State<_GraphComposeView> createState() => _GraphComposeViewState();
}

class _GraphComposeViewState extends State<_GraphComposeView> {
  final _controller = MarkdownTextEditingController();
  final _focusNode = FocusNode();
  bool _didPrefill = false;
  bool _didAutoPublish = false;
  bool _hasText = false;
  String? _avatarUrl;
  String _pubkeySeed = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _loadUserProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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

  Future<void> _openReferencePicker(BrahmaCreateState state) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<BrahmaCreateBloc>();
    final selected = state.selectedMentions
        .map((n) => ComposerReference(id: n.id, label: n.content))
        .toList();

    final result = await Navigator.push<List<ComposerReference>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReferencePickerPage(
          title: l10n.composerReferenceTitle,
          searchHint: l10n.brahmaMentionSearchHint,
          emptyLabel: l10n.brahmaMentionEmpty,
          selectedLabel: l10n.composerReferenceSelected,
          initialSelected: selected,
        ),
      ),
    );

    if (result != null && mounted) {
      // Rebuild selected mentions from the returned ids.
      bloc.add(RestoreDraftMentionsEvent(result.map((r) => r.id).toList()));
    }
  }

  void _saveDraft(BrahmaCreateState state) {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    context.read<BrahmaCreateBloc>().add(SaveDraftEvent(content: content));
  }

  void _publish(BrahmaCreateState state) {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    if (widget.initialDraftId != null) {
      context.read<BrahmaCreateBloc>().add(PublishDraftEvent(
            draftId: widget.initialDraftId!,
            content: content,
          ));
    } else {
      context.read<BrahmaCreateBloc>().add(SubmitNoteEvent(content: content));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<BrahmaCreateBloc, BrahmaCreateState>(
      listener: (context, state) {
        // Pre-fill from draft if requested
        if (!_didPrefill &&
            widget.initialDraftId != null &&
            state.drafts.isNotEmpty) {
          _didPrefill = true;
          try {
            final draft = state.drafts
                .firstWhere((d) => d.draftId == widget.initialDraftId);
            _controller.text = draft.content;
            _controller.selection =
                TextSelection.collapsed(offset: draft.content.length);
            // Restore saved references as selected mentions
            if (draft.eTagRefs.isNotEmpty) {
              context
                  .read<BrahmaCreateBloc>()
                  .add(RestoreDraftMentionsEvent(draft.eTagRefs));
            }
          } catch (_) {}

          if (widget.autoPublish && !_didAutoPublish) {
            _didAutoPublish = true;
            _publish(state);
          }
        }

        if (state.status == BrahmaCreateStatus.draftSaved) {
          Navigator.pop(context);
        }

        if (state.status == BrahmaCreateStatus.success) {
          // Pop the compose + graph routes back to the existing Home (Vishnu)
          // rather than goNamed, which rebuilds the shell and loses its state.
          Navigator.of(context).popUntil((route) => route.isFirst);
        }

        if (state.status == BrahmaCreateStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          (widget.initialDraftId != null && prev.drafts != curr.drafts),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          resizeToAvoidBottomInset: true,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                ComposeHeader(l10n: l10n),
                _MediaAttachStrip(state: state),
                UniunComposer(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 8,
                  maxLines: 14,
                  applyBottomInset: false,
                  markdownEnabled: true,
                  avatarUrl: _avatarUrl,
                  avatarSeed: _pubkeySeed,
                  hintText: l10n.brahmaHintText,
                  canSend: _hasText,
                  isSending: state.isSubmitting,
                  references: state.selectedMentions
                      .map((n) => ComposerReference(id: n.id, label: n.content))
                      .toList(),
                  onRemoveReference: (id) => context
                      .read<BrahmaCreateBloc>()
                      .add(RemoveMentionEvent(id)),
                  onAddReference: () => _openReferencePicker(state),
                  onDraft: () => _saveDraft(state),
                  draftLabel: l10n.brahmaDraft,
                  onSend: () => _publish(state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
