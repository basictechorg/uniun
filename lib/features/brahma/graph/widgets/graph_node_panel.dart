import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/vishnu/widgets/note_card.dart';

/// Slides up from the bottom when a graph node is tapped.
class GraphNodePanel extends StatelessWidget {
  const GraphNodePanel({
    super.key,
    required this.node,
    required this.onClose,
    this.profile,
    this.onEditTap,
    this.onPublishTap,
  });

  final GraphNodeData node;
  final VoidCallback onClose;
  final ProfileEntity? profile;

  final void Function(String draftId)? onEditTap;
  final void Function(String draftId)? onPublishTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDraft = node.type == GraphNodeType.draft;
    final noteEntity = node.created != null
        ? NoteEntity(
            id: node.eventId,
            sig: node.sig ?? '',
            authorPubkey: node.authorPubkey ?? '',
            content: node.content,
            type: NoteType.text,
            eTagRefs: node.eTagRefs,
            pTagRefs: node.pTagRefs,
            tTags: node.tTags,
            created: node.created!,
            isSeen: true,
          )
        : null;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.52,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header: type badge + close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TypeBadge(type: node.type, l10n: l10n),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Note content — NoteCard for saved/own, plain text for drafts
            if (noteEntity != null)
              Flexible(
                child: SingleChildScrollView(
                  child: NoteCard(
                    note: noteEntity,
                    profile: profile,
                    isSaved: node.type == GraphNodeType.saved,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.thread,
                      arguments: node.eventId,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    node.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),
              ),

            // Draft action buttons
            if (isDraft) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DraftActions(
                  draftId: node.eventId,
                  onClose: onClose,
                  onEditTap: onEditTap,
                  onPublishTap: onPublishTap,
                  l10n: l10n,
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Type badge ─────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.l10n});
  final GraphNodeType type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      GraphNodeType.saved => (l10n.graphLegendSaved, const Color(0xFF319BED)),
      GraphNodeType.own   => (l10n.graphLegendOwn,   const Color(0xFF059669)),
      GraphNodeType.draft => (l10n.graphLegendDraft,  const Color(0xFFD97706)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draft actions (Edit / Publish / Delete) ─────────────────────────────────
class _DraftActions extends StatelessWidget {
  const _DraftActions({
    required this.draftId,
    required this.onClose,
    required this.l10n,
    this.onEditTap,
    this.onPublishTap,
  });
  final String draftId;
  final VoidCallback onClose;
  final void Function(String)? onEditTap;
  final void Function(String)? onPublishTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          label: l10n.graphDraftEdit,
          color: AppColors.onSurfaceVariant,
          bgColor: AppColors.surfaceContainerLow,
          onTap: () {
            onClose();
            onEditTap?.call(draftId);
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionBtn(
            label: l10n.brahmaPublish,
            color: AppColors.onPrimary,
            bgColor: AppColors.primary,
            fullWidth: true,
            onTap: () {
              onClose();
              onPublishTap?.call(draftId);
            },
          ),
        ),
        const SizedBox(width: 8),
        // Delete
        _ActionBtn(
          label: l10n.graphDraftDelete,
          color: AppColors.error,
          bgColor: AppColors.errorContainer,
          onTap: () {
            onClose();
            context
                .read<GraphBloc>()
                .add(DeleteDraftNodeEvent(draftId));
          },
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.fullWidth = false,
  });
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: fullWidth ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
