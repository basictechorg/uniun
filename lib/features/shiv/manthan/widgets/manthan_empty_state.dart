import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/shiv/manthan/bloc/manthan_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Centered empty / terminal state widget for the Manthan deck area.
///
/// Renders different copy for [ManthanStatus.needsMoreNotes] and
/// [ManthanStatus.exhausted]. [onAddNotes] is fired when the CTA is tapped.
class ManthanEmptyState extends StatelessWidget {
  const ManthanEmptyState({
    super.key,
    required this.status,
    required this.onAddNotes,
  });

  final ManthanStatus status;
  final VoidCallback onAddNotes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (status) {
      ManthanStatus.needsMoreNotes => _EmptyStateBody(
          emoji: '✦',
          title: l10n.manthanEmptyNeedsMoreTitle,
          body: l10n.manthanEmptyNeedsMoreBody,
          ctaLabel: l10n.manthanEdgePublish, // reuses "Publish" action label
          onCta: onAddNotes,
        ),
      ManthanStatus.exhausted => _EmptyStateBody(
          emoji: '✦',
          title: l10n.manthanExhaustedTitle,
          body: l10n.manthanExhaustedBody,
          ctaLabel: l10n.manthanEdgePublish,
          onCta: onAddNotes,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _EmptyStateBody extends StatelessWidget {
  const _EmptyStateBody({
    required this.emoji,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  final String emoji;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _CtaButton(label: ctaLabel, onTap: onCta),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}
