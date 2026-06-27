import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';
import 'package:uniun/features/brahma/utils/brahma_scaffold_key.dart';
import 'package:uniun/l10n/app_localizations.dart';

// Mono-blue knowledge-graph palette (DESIGN.md §1.1) — one hue, sources by
// shade. The same fixed palette for the unscoped graph and every Manas view.
const graphNodeTypeColors = {
  GraphNodeType.saved: AppColors.graphNodeSaved,
  GraphNodeType.own:   AppColors.graphNodeOwn,
  GraphNodeType.draft: AppColors.graphNodeDraft,
};

/// Brahma graph app bar: a solid `logo · Brahma · search` header. The Brahma
/// logo opens the Manas drawer (where scope is changed); the search icon
/// reveals an inline field that highlights matching nodes (via
/// [SearchGraphEvent]).
class GraphHeader extends StatefulWidget {
  const GraphHeader({super.key});

  @override
  State<GraphHeader> createState() => _GraphHeaderState();
}

class _GraphHeaderState extends State<GraphHeader> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    _searchController.clear();
    context.read<GraphBloc>().add(const SearchGraphEvent(''));
    setState(() => _searchOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── App bar: menu · Brahma / search · search-toggle ──────────────
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/images/tabs/brahma.svg',
                      width: 32,
                      height: 32,
                      theme: const SvgTheme(
                        currentColor: AppColors.onSurfaceVariant,
                      ),
                    ),
                    tooltip: l10n.graphMenuTooltip,
                    onPressed: () =>
                        brahmaScaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: _searchOpen
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: (v) => context
                                .read<GraphBloc>()
                                .add(SearchGraphEvent(v)),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              hintText: l10n.graphSearchHint,
                              hintStyle: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  IconButton(
                    icon: Icon(
                      _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                    ),
                    color: AppColors.onSurface,
                    tooltip: _searchOpen
                        ? l10n.graphSearchClear
                        : l10n.graphSearchTooltip,
                    onPressed: _searchOpen ? _closeSearch : _openSearch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Source-shade legend — a design-system glass pill (DESIGN.md §2.2) overlaid
/// on the graph canvas. Nodes are always coloured by type, so it is fixed
/// regardless of Manas scope.
class GraphLegend extends StatelessWidget {
  const GraphLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(
              color: graphNodeTypeColors[GraphNodeType.saved]!,
              label: l10n.graphLegendSaved),
          const SizedBox(width: 12),
          _LegendDot(
              color: graphNodeTypeColors[GraphNodeType.own]!,
              label: l10n.graphLegendOwn),
          const SizedBox(width: 12),
          _LegendDot(
              color: graphNodeTypeColors[GraphNodeType.draft]!,
              label: l10n.graphLegendDraft),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
