import 'package:flutter/material.dart';
/// Shared container styling for the grouped cards on the Settings page.
///
/// Design-system "Settings group" (DESIGN.md §2.2): a white card lifted off the
/// off-white scaffold with a hairline border + soft shadow. One source of truth
/// so every settings card reads as the same contained group.
const double kSettingsCardRadius = 20;

BoxDecoration settingsCardDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(kSettingsCardRadius),
    border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
    boxShadow: [
      BoxShadow(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// Hairline used to separate rows inside a single Settings group card.
/// Lighter than the card border (the design's `--border-subtle`).
class SettingsRowDivider extends StatelessWidget {
  const SettingsRowDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
      );
}

/// A bordered card holding a vertical list of [SettingsRow]s separated by
/// hairline dividers — the mock's grouped-settings list. Pass bare rows; the
/// group inserts the dividers and clips ripples to the card radius.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SettingsRowDivider());
      rows.add(children[i]);
    }
    return Container(
      decoration: settingsCardDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSettingsCardRadius),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// A single row in a [SettingsGroup]: leading icon + label, an optional
/// descriptive subtitle below, an optional inline value on the right, and a
/// trailing chevron (or a custom [trailing] control such as a dropdown).
///
/// Mirrors the `Group` rows in `UNIUNDesignSystem/.../Settings.jsx`.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.infoTooltip,
    this.value,
    this.valueAccent = false,
    this.valueMono = false,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  /// Leading Material Symbols / Icons glyph.
  final IconData icon;
  final String label;

  /// Optional overrides for destructive / accented rows. Default to the muted
  /// icon + primary-text treatment shared by every other row.
  final Color? iconColor;
  final Color? labelColor;

  /// Descriptive line shown *below* the label (muted).
  final String? subtitle;

  /// When set, an info (ⓘ) icon sits next to the label; tapping it reveals a
  /// tooltip carrying this text. Used to tuck away an explanation that is too
  /// long to live inline as a [subtitle].
  final String? infoTooltip;

  /// Inline value shown on the right (e.g. active model, version).
  final String? value;
  final bool valueAccent;
  final bool valueMono;

  /// Custom trailing widget (dropdown/toggle). Replaces value + chevron.
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: labelColor ?? Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (infoTooltip != null) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: infoTooltip!,
                        triggerMode: TooltipTriggerMode.tap,
                        showDuration: const Duration(seconds: 6),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ..._buildTrailing(context),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  List<Widget> _buildTrailing(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (trailing != null) return [const SizedBox(width: 12), trailing!];
    final parts = <Widget>[];
    if (value != null) {
      parts.add(const SizedBox(width: 12));
      // Inflexible: the Expanded label absorbs all slack so the value (and the
      // chevron after it) hug the right edge. A Flexible here would reserve a
      // flex slot and leave a gap to the right of the chevron for short values.
      parts.add(
        Text(
          value!,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: valueAccent ? FontWeight.w600 : FontWeight.w500,
            fontFamily: valueMono ? 'monospace' : null,
            color:
                valueAccent ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (showChevron) {
      parts.add(const SizedBox(width: 6));
      parts.add(Icon(Icons.chevron_right_rounded,
          size: 20, color: colorScheme.outline));
    }
    return parts;
  }
}

/// One choice in a [showSettingsOptionSheet] picker.
class SettingsOption<T> {
  const SettingsOption(this.value, this.label);
  final T value;
  final String label;
}

/// Compact trailing control: the current value (accent) + a down chevron,
/// shrink-wrapped to the value. Replaces an inline `DropdownButton`, which
/// reserves the widest option's width and leaves a visible gap. Tapping it
/// opens a [showSettingsOptionSheet].
class SettingsPickerButton extends StatelessWidget {
  const SettingsPickerButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Single-choice bottom-sheet picker. The current [selected] option is checked;
/// picking one fires [onSelected] and dismisses the sheet.
Future<void> showSettingsOptionSheet<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<SettingsOption<T>> options,
  required ValueChanged<T> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            for (final o in options)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  onSelected(o.value);
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: o.value == selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: o.value == selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (o.value == selected)
                        Icon(Icons.check_rounded,
                            size: 20, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
