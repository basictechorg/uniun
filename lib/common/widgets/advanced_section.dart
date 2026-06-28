import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// A collapsible "Advanced" section, collapsed by default.
///
/// Its [children] stay mounted even while collapsed (kept in the tree via
/// [Offstage] rather than conditionally built), so any field inside that
/// applies a default on first build — e.g. [RelaySelectorField], which
/// auto-selects the UNIUN relay — still does so without the user ever opening
/// the section. This lets surfaces hide relay pickers (and other power-user
/// settings) from normal users while keeping publishing working out of the box.
class AdvancedSection extends StatefulWidget {
  const AdvancedSection({super.key, required this.children, this.label});

  final List<Widget> children;

  /// Header label. Defaults to the localized "Advanced".
  final String? label;

  @override
  State<AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<AdvancedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label ?? AppLocalizations.of(context)!.commonAdvanced;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded,
                    size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.neutral400),
                ),
              ],
            ),
          ),
        ),
        // Children stay in the tree so first-build defaults (e.g. relay
        // auto-select) apply even while collapsed; Offstage just hides them.
        Offstage(
          offstage: !_expanded,
          child: TickerMode(
            enabled: _expanded,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
