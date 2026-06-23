import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/features/shiv/manthan/bloc/manthan_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Manthan drawer section: the Manas list that scopes the deck. "All notes"
/// plus every Manas; tapping one dispatches [ManthanEvent.changeScope] on the
/// ambient [ManthanBloc] and closes the drawer. Must sit under the deck's
/// `BlocProvider<ManthanBloc>` (it does — the drawer is the deck Scaffold's).
class ManthanScopeDrawerSection extends StatelessWidget {
  const ManthanScopeDrawerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Text(
            l10n.manthanScopeSheetTitle.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        BlocBuilder<ManthanBloc, ManthanState>(
          buildWhen: (prev, curr) =>
              prev.manasIds != curr.manasIds ||
              prev.manasOptions != curr.manasOptions,
          builder: (context, state) {
            void select(List<String> ids) {
              Navigator.of(context).pop();
              context.read<ManthanBloc>().add(ManthanEvent.changeScope(ids));
            }

            return Column(
              children: [
                _ScopeRow(
                  leading: Icon(
                    Icons.hub_rounded,
                    size: 18,
                    color: state.manasIds.isEmpty
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  label: l10n.manthanScopeAllNotes,
                  isSelected: state.manasIds.isEmpty,
                  onTap: () => select(const []),
                ),
                for (final m in state.manasOptions)
                  _ScopeRow(
                    leading: Icon(
                      ManasIcons.byName(m.iconName),
                      size: 18,
                      color: state.manasIds.contains(m.manasId)
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                    label: m.name,
                    noteCount: m.noteCount,
                    isSelected: state.manasIds.contains(m.manasId),
                    onTap: () => select([m.manasId]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.leading,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.noteCount,
  });

  final Widget leading;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? noteCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: leading,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (noteCount != null)
              Text(
                '$noteCount',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
