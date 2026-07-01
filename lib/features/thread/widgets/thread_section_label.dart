import 'package:flutter/material.dart';

/// UPPERCASE wide-tracked eyebrow shown above the references and replies groups
/// in the thread view (mirrors the design-system `SectionLabel`): a small
/// leading icon + a tracked, muted, uppercase label.
class ThreadSectionLabel extends StatelessWidget {
  const ThreadSectionLabel(this.label, {super.key, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ],
    );
  }
}
