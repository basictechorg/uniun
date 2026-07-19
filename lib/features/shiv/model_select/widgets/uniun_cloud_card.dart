import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/shiv/model_select/widgets/model_card.dart';

/// The no-download path on the model selection screen: run Shiv on UNIUN
/// Cloud. Tapping signs in silently with the user's identity keys; the
/// plan's models then render as [CloudModelTile]s below.
class UniunCloudCard extends StatelessWidget {
  const UniunCloudCard({
    super.key,
    required this.isConnecting,
    required this.onTap,
  });

  final bool isConnecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.03),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: scheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isConnecting
                    ? DropLoadingIndicator(size: 24, color: scheme.primary)
                    : Icon(Icons.cloud_outlined,
                        size: 28, color: scheme.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.aiModelCloudTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      ModelCapabilityChip(
                        label: l10n.aiModelCloudBadge,
                        isSelected: true,
                        icon: Icons.download_for_offline_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConnecting
                        ? l10n.cloudProviderConnecting
                        : l10n.aiModelCloudSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One plan-allowed cloud model, shown under [UniunCloudCard] once signed in.
/// Tapping activates it (backend + model) and finishes the screen.
class CloudModelTile extends StatelessWidget {
  const CloudModelTile({
    super.key,
    required this.model,
    required this.isActive,
    required this.isActivating,
    required this.onTap,
  });

  final LlmModelInfo model;
  final bool isActive;
  final bool isActivating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isActivating ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.05)
              : scheme.surface,
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 18,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                model.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActivating)
              DropLoadingIndicator(size: 16, color: scheme.primary)
            else if (isActive)
              ModelCapabilityChip(
                label: l10n.aiModelAlreadyActive,
                isSelected: true,
                icon: Icons.check_circle_rounded,
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
