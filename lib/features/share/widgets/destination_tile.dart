import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_custom_colors.dart';

/// Flat destination row used by both share sheets — a tinted square icon chip,
/// title (+ optional subtitle), and an optional "selected" check. Mirrors the
/// design-system share rows (`UNIUNDesignSystem/.../ShareSheet.jsx`).
class DestinationTile extends StatelessWidget {
  const DestinationTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.selected = false,
  }) : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// When true the row reads as picked (tint wash + trailing check). Used by
  /// the select-then-confirm outbound sheet; the incoming sheet leaves it false
  /// so a tap acts immediately.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              leading ??
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.custom.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
