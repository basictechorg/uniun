import 'package:flutter/material.dart';
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
      icon: Icon(
        Icons.qr_code_rounded,
        color: Theme.of(context).colorScheme.primary,
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
      icon: Icon(
        Icons.qr_code_scanner_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
