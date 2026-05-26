import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/features/brahma/graph/models/graph_node_type.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

const graphNodeTypeColors = {
  GraphNodeType.saved: AppColors.graphSaved,
  GraphNodeType.own:   AppColors.graphOwn,
  GraphNodeType.draft: AppColors.graphDraft,
};

/// Top header: back arrow, title, colour legend.
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
          const SizedBox(width: 16),
          SizedBox(
            width: 36,
            height: 36,
            child: SvgPicture.asset(
              'assets/images/tabs/brahma.svg',
              fit: BoxFit.contain,
              semanticsLabel: l10n.navBrahma,
            ),
          ),
          const Spacer(),
          _LegendRow(l10n: l10n),
        ],
      ),
    );
  }
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
