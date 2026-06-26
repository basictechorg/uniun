import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// The "All notes" scope icon — same as the Brahma drawer's whole-library entry.
const IconData kAllNotesIcon = Icons.all_inclusive_rounded;

/// The scope the composer-chat reasons over: a specific Manas, or the whole
/// library (`manasIds` empty). [icon] is the resolved icon to show in the
/// composer avatar while chatting in this scope.
class ManasChatScope {
  const ManasChatScope({
    required this.manasIds,
    required this.icon,
    this.name,
  });

  final List<String> manasIds;
  final String? name;
  final IconData icon;
}

/// Long-press the composer avatar → pick which Manas the inline chat should be
/// grounded in. Returns null if dismissed. Reuses [GetManasListUseCase].
/// [current] is the scope already in effect — its row renders with a selected
/// check; pass null when no scope is active yet.
Future<ManasChatScope?> showManasChatPicker(
  BuildContext context, {
  ManasChatScope? current,
}) {
  return showModalBottomSheet<ManasChatScope>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ManasPickerSheet(current: current),
  );
}

class _ManasPickerSheet extends StatelessWidget {
  const _ManasPickerSheet({this.current});

  final ManasChatScope? current;

  bool get _allSelected => current != null && current!.manasIds.isEmpty;

  bool _isSelected(String manasId) =>
      current != null &&
      current!.manasIds.length == 1 &&
      current!.manasIds.first == manasId;

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
              l10n.composerChatPickerTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.composerChatPickerSubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
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
                  child: FutureBuilder(
                    future: getIt<GetManasListUseCase>().call(),
                    builder: (context, snapshot) {
                      final list = snapshot.hasData
                          ? snapshot.data!.fold((_) => <ManasEntity>[], (l) => l)
                          : <ManasEntity>[];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ScopeTile(
                            icon: kAllNotesIcon,
                            isAllNotes: true,
                            title: l10n.composerChatAllNotes,
                            subtitle: l10n.composerChatAllNotesSubtitle,
                            selected: _allSelected,
                            showDivider: false,
                            onTap: () => Navigator.pop(
                              context,
                              const ManasChatScope(
                                  manasIds: [], icon: kAllNotesIcon),
                            ),
                          ),
                          if (!snapshot.hasData)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: DropLoadingIndicator(size: 22),
                                ),
                              ),
                            ),
                          for (final m in list)
                            _ScopeTile(
                              icon: ManasIcons.byName(m.iconName),
                              title: m.name,
                              subtitle: l10n.composerChatManasNotes(m.noteCount),
                              selected: _isSelected(m.manasId),
                              showDivider: true,
                              onTap: () => Navigator.pop(
                                context,
                                ManasChatScope(
                                  manasIds: [m.manasId],
                                  name: m.name,
                                  icon: ManasIcons.byName(m.iconName),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
    required this.subtitle,
    required this.selected,
    required this.showDivider,
    required this.onTap,
    this.isAllNotes = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool showDivider;
  final bool isAllNotes;
  final VoidCallback onTap;

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
                  color: isAllNotes
                      ? AppColors.surfaceContainer
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
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
