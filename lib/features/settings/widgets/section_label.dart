import 'package:flutter/material.dart';
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.label, {super.key, this.icon, this.leading});

  final String label;
  final IconData? icon;

  /// Custom leading widget, used instead of [icon] when provided.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 6),
        ] else if (icon != null) ...[
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
        ],
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
