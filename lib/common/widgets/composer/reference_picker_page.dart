import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Full-screen picker for attaching note/message references to a composer.
///
/// Fully presentational: the caller supplies a [onSearch] callback that maps a
/// query to candidate [ComposerReference]s (in-memory filter, relay search,
/// whatever the source needs). The page maintains the working selection and
/// returns the final `List<ComposerReference>` via `Navigator.pop`.
class ReferencePickerPage extends StatefulWidget {
  const ReferencePickerPage({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyLabel,
    required this.selectedLabel,
    required this.onSearch,
    this.initialSelected = const [],
  });

  final String title;
  final String searchHint;
  final String emptyLabel;
  final String selectedLabel;
  final Future<List<ComposerReference>> Function(String query) onSearch;
  final List<ComposerReference> initialSelected;

  @override
  State<ReferencePickerPage> createState() => _ReferencePickerPageState();
}

class _ReferencePickerPageState extends State<ReferencePickerPage> {
  final _searchController = TextEditingController();
  late final List<ComposerReference> _selected =
      List.of(widget.initialSelected);
  List<ComposerReference> _results = const [];
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _query = query;
      _loading = true;
    });
    final results = await widget.onSearch(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    // Selected first, then results not already selected.
    final rows = <ComposerReference>[
      ..._selected,
      ..._results.where((r) => !_selected.any((s) => s.id == r.id)),
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _runSearch,
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
                      child: _loading
                          ? const CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2)
                          : Text(
                              _query.trim().isEmpty ? widget.searchHint : widget.emptyLabel,
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
