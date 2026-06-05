import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/features/brahma/graph/widgets/compose_header.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/common/widgets/composer/reference_picker_page.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
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

class _GraphComposeView extends StatefulWidget {
  const _GraphComposeView({this.initialDraftId, this.autoPublish = false});
  final String? initialDraftId;
  final bool autoPublish;

  @override
  State<_GraphComposeView> createState() => _GraphComposeViewState();
}

class _GraphComposeViewState extends State<_GraphComposeView> {
  final _controller = TextEditingController();
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
          Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
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
                UniunComposer(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 8,
                  maxLines: 14,
                  applyBottomInset: false,
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
