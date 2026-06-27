import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// The all-notes ("Brahma") scope icon — same as the Nataraj deck drawer's
/// whole-library entry.
const IconData kNatarajAllNotesIcon = Icons.hub_rounded;

/// Bottom-sheet Manas selector for the Nataraj deck, opened from the header
/// selector button. Mirrors the scope list in [NatarajScopeDrawerSection] but
/// as a modal sheet: "Brahma" (all notes, empty ids) plus every Manas. Tapping
/// a row pops the sheet and reports the chosen scope via [onSelect] — the caller
/// dispatches [NatarajEvent.changeScope]. The sheet itself holds no bloc.
Future<void> showNatarajScopeSheet(
  BuildContext context, {
  required List<ManasEntity> options,
  required List<String> selectedIds,
  required ValueChanged<List<String>> onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NatarajScopeSheet(
      options: options,
      selectedIds: selectedIds,
      onSelect: onSelect,
    ),
  );
}

class _NatarajScopeSheet extends StatelessWidget {
  const _NatarajScopeSheet({
    required this.options,
    required this.selectedIds,
    required this.onSelect,
  });

  final List<ManasEntity> options;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onSelect;

  bool get _allSelected => selectedIds.isEmpty;

  bool _isSelected(String manasId) =>
      selectedIds.length == 1 && selectedIds.first == manasId;

  void _select(BuildContext context, List<String> ids) {
    Navigator.of(context).pop();
    onSelect(ids);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 2, bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              l10n.natarajScopeSheetTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSubtle),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScopeTile(
                        icon: kNatarajAllNotesIcon,
                        title: l10n.natarajScopeAllNotes,
                        selected: _allSelected,
                        showDivider: false,
                        onTap: () => _select(context, const []),
                      ),
                      for (final m in options)
                        _ScopeTile(
                          icon: ManasIcons.byName(m.iconName),
                          title: m.name,
                          noteCount: m.noteCount,
                          selected: _isSelected(m.manasId),
                          showDivider: true,
                          onTap: () => _select(context, [m.manasId]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.showDivider,
    required this.onTap,
    this.noteCount,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;
  final int? noteCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color:
                        selected ? AppColors.primary : AppColors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (noteCount != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$noteCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.neutral400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
