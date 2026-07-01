import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/features/shiv/nataraj/bloc/nataraj_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Nataraj drawer section: the Manas list that scopes the deck. "All notes"
/// plus every Manas; tapping one dispatches [NatarajEvent.changeScope] on the
/// ambient [NatarajBloc] and closes the drawer. Must sit under the deck's
/// `BlocProvider<NatarajBloc>` (it does — the drawer is the deck Scaffold's).
class NatarajScopeDrawerSection extends StatelessWidget {
  const NatarajScopeDrawerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Text(
            l10n.natarajScopeSheetTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        BlocBuilder<NatarajBloc, NatarajState>(
          buildWhen: (prev, curr) =>
              prev.manasIds != curr.manasIds ||
              prev.manasOptions != curr.manasOptions,
          builder: (context, state) {
            void select(List<String> ids) {
              Navigator.of(context).pop();
              context.read<NatarajBloc>().add(NatarajEvent.changeScope(ids));
            }

            return Column(
              children: [
                _ScopeRow(
                  leading: Icon(
                    Icons.hub_rounded,
                    size: 18,
                    color: state.manasIds.isEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  label: l10n.natarajScopeAllNotes,
                  isSelected: state.manasIds.isEmpty,
                  onTap: () => select(const []),
                ),
                for (final m in state.manasOptions)
                  _ScopeRow(
                    leading: Icon(
                      ManasIcons.byName(m.iconName),
                      size: 18,
                      color: state.manasIds.contains(m.manasId)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (noteCount != null)
              Text(
                '$noteCount',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}
