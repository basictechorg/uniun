import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/cubit/reference_picker_cubit.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Full-screen picker for attaching note/message references to a composer.
///
/// Self-contained: queries the unified `Note` collection via
/// [ReferencePickerCubit] (recent + search) and the saved-note table, with an
/// All / Saved tab filter. The page maintains the working selection and returns
/// the final `List<ComposerReference>` via `Navigator.pop`.
class ReferencePickerPage extends StatelessWidget {
  const ReferencePickerPage({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyLabel,
    required this.selectedLabel,
    this.initialSelected = const [],
  });

  final String title;
  final String searchHint;
  final String emptyLabel;
  final String selectedLabel;
  final List<ComposerReference> initialSelected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReferencePickerCubit>(),
      child: _ReferencePickerView(
        title: title,
        searchHint: searchHint,
        emptyLabel: emptyLabel,
        selectedLabel: selectedLabel,
        initialSelected: initialSelected,
      ),
    );
  }
}

class _ReferencePickerView extends StatefulWidget {
  const _ReferencePickerView({
    required this.title,
    required this.searchHint,
    required this.emptyLabel,
    required this.selectedLabel,
    required this.initialSelected,
  });

  final String title;
  final String searchHint;
  final String emptyLabel;
  final String selectedLabel;
  final List<ComposerReference> initialSelected;

  @override
  State<_ReferencePickerView> createState() => _ReferencePickerViewState();
}

class _ReferencePickerViewState extends State<_ReferencePickerView> {
  final _searchController = TextEditingController();
  late final List<ComposerReference> _selected =
      List.of(widget.initialSelected);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(ComposerReference ref) {
    setState(() {
      final idx = _selected.indexWhere((r) => r.id == ref.id);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(ref);
      }
    });
  }

  void _onTabChanged(ReferenceTab tab) {
    _searchController.clear();
    context.read<ReferencePickerCubit>().setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pickerState = context.watch<ReferencePickerCubit>().state;

    // Selected first, then results not already selected.
    final rows = <ComposerReference>[
      ..._selected,
      ...pickerState.results.where((r) => !_selected.any((s) => s.id == r.id)),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _selected);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: UniunBackButton(
            onPressed: () => Navigator.pop(context, _selected),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: const Icon(Icons.check_rounded, color: AppColors.primary),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<ReferenceTab>(
                segments: [
                  ButtonSegment(
                    value: ReferenceTab.all,
                    label: Text(l10n.composerReferenceTabAll),
                  ),
                  ButtonSegment(
                    value: ReferenceTab.saved,
                    label: Text(l10n.composerReferenceTabSaved),
                  ),
                ],
                selected: {pickerState.tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _onTabChanged(s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (q) => context.read<ReferencePickerCubit>().search(q),
                style:
                    const TextStyle(fontSize: 14, color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
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
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: pickerState.loading
                          ? const DropLoadingIndicator(
                              color: AppColors.primary)
                          : Text(
                              widget.emptyLabel,
                              style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 14),
                            ),
                    )
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final ref = rows[i];
                        final isSelected =
                            _selected.any((s) => s.id == ref.id);
                        return _ResultTile(
                          reference: ref,
                          isSelected: isSelected,
                          selectedLabel: widget.selectedLabel,
                          onTap: () => _toggle(ref),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.reference,
    required this.isSelected,
    required this.selectedLabel,
    required this.onTap,
  });

  final ComposerReference reference;
  final bool isSelected;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = reference.label.trim();
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
                color:
                    isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Text(
                selectedLabel,
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
