import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Atomic back-arrow used as the `leading` of every page-level [AppBar].
///
/// Standardises on iOS-style chevron (`arrow_back_ios_new`) in
/// [AppColors.primary] — replacing the mix of `arrow_back` (Material) and
/// `arrow_back_ios_new` (iOS) plus assorted colors across pages.
///
/// Default `onPressed` falls back to `context.pop()` (GoRouter); pass a
/// custom callback when the screen needs to confirm before leaving.
class UniunBackButton extends StatelessWidget {
  const UniunBackButton({
    super.key,
    this.onPressed,
    this.color = AppColors.primary,
  });

  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: Icon(Icons.arrow_back_ios_new, color: color, size: 20),
      tooltip: l10n.actionBack,
      onPressed: onPressed ?? () => context.pop(),
    );
  }
}
