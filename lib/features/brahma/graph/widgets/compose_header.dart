import 'package:flutter/material.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Top header for the compose page (back arrow + title + pen icon).
class ComposeHeader extends StatelessWidget {
  const ComposeHeader({super.key, required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          UniunBackButton(
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            l10n.navBrahma,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
