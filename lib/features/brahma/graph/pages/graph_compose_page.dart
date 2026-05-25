import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/features/brahma/graph/widgets/compose_action_bar.dart';
import 'package:uniun/features/brahma/graph/widgets/compose_header.dart';
import 'package:uniun/features/brahma/graph/widgets/mention_chips.dart';
import 'package:uniun/features/brahma/graph/widgets/mention_search_panel.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
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
  bool _showMentionPanel = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _closeMentionPanel() {
    context.read<BrahmaCreateBloc>().add(const ClearMentionSearchEvent());
    setState(() => _showMentionPanel = false);
  }

  void _onMentionSelected(NoteEntity note, bool isSelected) {
    final bloc = context.read<BrahmaCreateBloc>();
    if (isSelected) {
      bloc.add(RemoveMentionEvent(note.id));
    } else {
      bloc.add(AddMentionEvent(note));
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

                if (state.selectedMentions.isNotEmpty)
                  MentionChips(
                    mentions: state.selectedMentions,
                    onRemove: (id) => context
                        .read<BrahmaCreateBloc>()
                        .add(RemoveMentionEvent(id)),
                  ),

                // Text area — auto-expands, scrolls internally when constrained
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      minLines: 4,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.onSurface,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.brahmaHintText,
                        hintStyle: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                ComposeActionBar(
                  state: state,
                  onDraft: () => _saveDraft(state),
                  onPublish: () => _publish(state),
                  onMentionTap: () {
                    _focusNode.unfocus();
                    setState(() => _showMentionPanel = true);
                  },
                  l10n: l10n,
                ),
              ],
            ),
          ),

          bottomSheet: _showMentionPanel
              ? MentionSearchPanel(
                  state: state,
                  onClose: _closeMentionPanel,
                  onSelect: _onMentionSelected,
                  l10n: l10n,
                )
              : null,
        );
      },
    );
  }
}
