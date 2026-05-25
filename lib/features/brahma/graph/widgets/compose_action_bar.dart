import 'package:flutter/material.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Bottom action bar for the compose page: link-reference button, Draft, Publish.
class ComposeActionBar extends StatelessWidget {
  const ComposeActionBar({
    super.key,
    required this.state,
    required this.onDraft,
    required this.onPublish,
    required this.onMentionTap,
    required this.l10n,
  });

  final BrahmaCreateState state;
  final VoidCallback onDraft;
  final VoidCallback onPublish;
  final VoidCallback onMentionTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isSubmitting = state.isSubmitting;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          // Link / reference button
          GestureDetector(
            onTap: onMentionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_rounded,
                  size: 18, color: AppColors.primary),
            ),
          ),
          const Spacer(),

          // Draft button
          GestureDetector(
            onTap: isSubmitting ? null : onDraft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.brahmaDraft,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Publish button
          GestureDetector(
            onTap: isSubmitting ? null : onPublish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      l10n.brahmaPublish,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
