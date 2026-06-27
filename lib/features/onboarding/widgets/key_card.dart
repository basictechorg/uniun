import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// A single Nostr key row: an uppercase label, a muted helper line, and an
/// inset field showing the key value (mono) with a copy control and, for the
/// secret key, a reveal toggle.
class KeyCard extends StatelessWidget {
  const KeyCard({
    super.key,
    required this.label,
    required this.helper,
    required this.keyValue,
    required this.isSecret,
    required this.isVisible,
    required this.onToggle,
    required this.isCopied,
    required this.onCopy,
  });

  final String label;
  final String helper;
  final String keyValue;
  final bool isSecret;
  final bool isVisible;
  final VoidCallback? onToggle;
  final bool isCopied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final hidden = isSecret && !isVisible;
    final display = hidden ? '• • • • • • • • • • • •' : keyValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.outline,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.2,
                    color: hidden
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface,
                  ),
                ),
              ),
              if (onToggle != null)
                _KeyIconButton(
                  icon: isVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  onTap: onToggle,
                ),
              const SizedBox(width: 2),
              _CopyButton(isCopied: isCopied, onCopy: onCopy),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact circular tap target for the in-field key actions (copy / reveal).
class _KeyIconButton extends StatelessWidget {
  const _KeyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Labeled "Copy" action rendered as a tinted pill so the control clearly reads
/// as a tappable button (not just an icon). Flips to a check + "Copied" once
/// tapped, matching the key-card's copy-to-proceed flow.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.isCopied, required this.onCopy});

  final bool isCopied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCopied ? null : onCopy,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isCopied ? 0.0 : 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCopied
                    ? Icons.check_rounded
                    : Icons.content_copy_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                isCopied ? l10n.actionCopied : l10n.actionCopy,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
