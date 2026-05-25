import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Bottom sheet panel for searching and selecting note references (mentions).
class MentionSearchPanel extends StatefulWidget {
  const MentionSearchPanel({
    super.key,
    required this.state,
    required this.onClose,
    required this.onSelect,
    required this.l10n,
  });

  final BrahmaCreateState state;
  final VoidCallback onClose;
  final void Function(NoteEntity note, bool isSelected) onSelect;
  final AppLocalizations l10n;

  @override
  State<MentionSearchPanel> createState() => _MentionSearchPanelState();
}

class _MentionSearchPanelState extends State<MentionSearchPanel> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  widget.l10n.brahmaMentionSheetTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.onSurfaceVariant),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (q) {
                if (q.trim().isEmpty) {
                  context
                      .read<BrahmaCreateBloc>()
                      .add(const ClearMentionSearchEvent());
                } else {
                  context
                      .read<BrahmaCreateBloc>()
                      .add(SearchMentionsEvent(q.trim()));
                }
              },
              style: const TextStyle(fontSize: 14, color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: widget.l10n.brahmaMentionSearchHint,
                hintStyle: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.onSurfaceVariant),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Results
          Flexible(
            child: _search.text.trim().isEmpty &&
                    state.selectedMentions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.l10n.brahmaMentionSearchHint,
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 14),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      ...state.selectedMentions.map((n) => _ResultTile(
                            note: n,
                            isSelected: true,
                            l10n: widget.l10n,
                            onTap: () => widget.onSelect(n, true),
                          )),
                      ...state.mentionResults
                          .where((n) => !state.selectedMentions
                              .any((s) => s.id == n.id))
                          .map((n) => _ResultTile(
                                note: n,
                                isSelected: false,
                                l10n: widget.l10n,
                                onTap: () => widget.onSelect(n, false),
                              )),
                      if (state.mentionResults.isEmpty &&
                          _search.text.trim().isNotEmpty &&
                          !state.isMentionSearching)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.l10n.brahmaMentionEmpty,
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 14),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Search result tile ────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.note,
    required this.isSelected,
    required this.l10n,
    required this.onTap,
  });

  final NoteEntity note;
  final bool isSelected;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = note.content.trim();
    final label = preview.length > 100
        ? '${preview.substring(0, 100)}…'
        : preview.isEmpty
            ? '…'
            : preview;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? Icons.check_rounded : Icons.article_outlined,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Text(
                l10n.brahmaMentionSelected,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
