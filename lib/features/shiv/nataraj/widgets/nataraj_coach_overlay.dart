import 'package:flutter/material.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Full-screen coach overlay shown once when the user first opens Nataraj.
///
/// Renders a 3×3 grid illustrating the four swipe directions around a central
/// card placeholder. Tapping [l10n.natarajCoachDismiss] calls [onDismiss].
class NatarajCoachOverlay extends StatelessWidget {
  const NatarajCoachOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: const Color(0xC7191C1E), // ~78% dark scrim
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.natarajCoachTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _DirectionGrid(l10n: l10n),
                const SizedBox(height: 28),
                _GotItButton(onTap: onDismiss, label: l10n.natarajCoachDismiss),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionGrid extends StatelessWidget {
  const _DirectionGrid({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Table(
        children: [
          // Row 1: empty | Publish | empty
          TableRow(children: [
            const SizedBox.shrink(),
            _Cell(icon: '↑', label: l10n.natarajEdgePublish),
            const SizedBox.shrink(),
          ]),
          // Row 2: Discard | Card | Draft
          TableRow(children: [
            _Cell(icon: '←', label: l10n.natarajEdgeDiscard),
            _CenterCard(),
            _Cell(icon: '→', label: l10n.natarajEdgeDraft),
          ]),
          // Row 3: empty | Discuss | empty
          TableRow(children: [
            const SizedBox.shrink(),
            _Cell(icon: '↓', label: l10n.natarajEdgeDiscuss),
            const SizedBox.shrink(),
          ]),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          '▭',
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GotItButton extends StatelessWidget {
  const _GotItButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
