import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Brand-blue QR icon used in AppBars / drawer headers to open a QR card.
class UniunQrButton extends StatelessWidget {
  const UniunQrButton({
    super.key,
    required this.onTap,
    this.tooltip,
  });
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: const Icon(
        Icons.qr_code_rounded,
        color: AppColors.primary,
      ),
    );
  }
}

/// Sibling — opens the unified scanner.
class UniunQrScanButton extends StatelessWidget {
  const UniunQrScanButton({
    super.key,
    required this.onTap,
    this.tooltip,
  });
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: const Icon(
        Icons.qr_code_scanner_rounded,
        color: AppColors.primary,
      ),
    );
  }
}
