import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';
import 'package:uniun/features/brahma/utils/brahma_scaffold_key.dart';
import 'package:uniun/features/brahma/utils/manas_colors.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/l10n/app_localizations.dart';

const graphNodeTypeColors = {
  GraphNodeType.saved: AppColors.graphSaved,
  GraphNodeType.own:   AppColors.graphOwn,
  GraphNodeType.draft: AppColors.graphDraft,
};

/// Top header: brahma logo + (when scoped to a Manas) the Manas name and
/// an edit affordance, plus the colour legend.
class GraphHeader extends StatelessWidget {
  const GraphHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.only(
        right: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Tap the Brahma logo to open the side drawer — mirrors Vishnu's
          // top-left avatar tap. Edge-swipe from the left also opens it.
          InkWell(
            onTap: () => brahmaScaffoldKey.currentState?.openDrawer(),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: 36,
                height: 36,
                child: SvgPicture.asset(
                  'assets/images/tabs/brahma.svg',
                  fit: BoxFit.contain,
                  semanticsLabel: l10n.navBrahma,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BlocBuilder<GraphBloc, GraphState>(
              buildWhen: (prev, curr) =>
                  prev.scopedManasId != curr.scopedManasId ||
                  prev.scopedManasName != curr.scopedManasName,
              builder: (context, state) {
                if (state.scopedManasId == null) {
                  return const SizedBox.shrink();
                }
                final label =
                    state.scopedManasName ?? l10n.graphHeaderUnnamedManas;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FutureBuilder<String?>(
                        // Resolve the scoped Manas's iconName for the chip.
                        // GraphState doesn't carry it (yet) so we look it up
                        // — cheap one-row Isar query.
                        future: _resolveIconName(state.scopedManasId!),
                        builder: (context, snapshot) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ManasIcons.byName(snapshot.data),
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppColors.primary,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.graphHeaderManasEditTooltip,
                      onPressed: () => context.pushNamed(
                        AppRoutes.brahmaManasForm,
                        extra: {'manasId': state.scopedManasId},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          BlocBuilder<GraphBloc, GraphState>(
            buildWhen: (prev, curr) =>
                prev.scopedManasId != curr.scopedManasId ||
                prev.scopedManasColorHexes != curr.scopedManasColorHexes,
            builder: (context, state) {
              // When scoped to a Manas with a chosen palette, swap the
              // default 3-dot legend for the Manas swatches (saved/own/draft
              // distinctions don't exist inside a saved-only Manas). When
              // scoped without a palette, keep the unscoped legend so the
              // user still has the colour key.
              if (state.scopedManasId != null &&
                  state.scopedManasColorHexes.isNotEmpty) {
                return _ManasSwatchesRow(
                  hexes: state.scopedManasColorHexes,
                  label: state.scopedManasName ??
                      l10n.graphHeaderUnnamedManas,
                );
              }
              return _LegendRow(l10n: l10n);
            },
          ),
        ],
      ),
    );
  }
}

class _ManasSwatchesRow extends StatelessWidget {
  const _ManasSwatchesRow({required this.hexes, required this.label});
  final List<String> hexes;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < hexes.length; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ManasColors.parse(hexes[i]),
              shape: BoxShape.circle,
            ),
          ),
          if (i < hexes.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

Future<String?> _resolveIconName(String manasId) async {
  final res = await getIt<GetManasByIdUseCase>().call(manasId);
  return res.fold((_) => null, (m) => m.iconName);
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: graphNodeTypeColors[GraphNodeType.saved]!, label: l10n.graphLegendSaved),
        const SizedBox(width: 8),
        _LegendDot(color: graphNodeTypeColors[GraphNodeType.own]!, label: l10n.graphLegendOwn),
        const SizedBox(width: 8),
        _LegendDot(color: graphNodeTypeColors[GraphNodeType.draft]!, label: l10n.graphLegendDraft),
      ],
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
