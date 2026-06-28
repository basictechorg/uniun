import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';

// Five distinguishable hues for the stacked bar. Sourced from AppColors
// so the chart re-themes with the rest of the app.
const _kColorAiModels = AppColors.graphOwn;       // green
const _kColorChatHistory = AppColors.graphDraft;  // orange
const _kColorMedia = AppColors.secondary;         // muted blue (≠ primary)
const _kColorOther = AppColors.outline;           // gray

/// Human-readable byte size (KB / MB / GB). Shared by the metrics row value
/// and the metrics sheet.
String formatStorageBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

// ── Settings rows ───────────────────────────────────────────────────────────────

/// Storage → "Show metrics" row. The right-hand value is the live total used;
/// tapping opens the breakdown bottom sheet.
class StorageMetricsRow extends StatelessWidget {
  const StorageMetricsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<StorageCubit, StorageState>(
      buildWhen: (a, b) => a.totalBytes != b.totalBytes || a.isLoading != b.isLoading,
      builder: (context, state) {
        return SettingsRow(
          icon: Icons.donut_small_rounded,
          label: l10n.storageShowMetrics,
          value: state.isLoading ? '…' : formatStorageBytes(state.totalBytes),
          valueAccent: true,
          onTap: () => showStorageMetricsSheet(context),
        );
      },
    );
  }
}

/// Storage → "Remove data" row. Red to flag the destructive intent; opens the
/// removal options sheet.
class RemoveDataRow extends StatelessWidget {
  const RemoveDataRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<StorageCubit, StorageState>(
      buildWhen: (a, b) =>
          a.isDeleting != b.isDeleting ||
          a.isDeletingChatHistory != b.isDeletingChatHistory,
      builder: (context, state) {
        final busy = state.isDeleting || state.isDeletingChatHistory;
        return SettingsRow(
          icon: Icons.delete_outline_rounded,
          iconColor: AppColors.error,
          label: l10n.storageRemoveData,
          labelColor: AppColors.error,
          showChevron: false,
          trailing: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: DropLoadingIndicator(size: 18, color: AppColors.error),
                )
              : const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.error),
          onTap: busy ? null : () => showRemoveDataSheet(context),
        );
      },
    );
  }
}

// ── Metrics bottom sheet ────────────────────────────────────────────────────────

/// Opens the storage-breakdown bottom sheet (the chart that used to live inline
/// on the settings page).
Future<void> showStorageMetricsSheet(BuildContext context) {
  final cubit = context.read<StorageCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _StorageMetricsSheet(),
    ),
  );
}

class _StorageMetricsSheet extends StatelessWidget {
  const _StorageMetricsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: BlocBuilder<StorageCubit, StorageState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.storageUsage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (state.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: DropLoadingIndicator(color: AppColors.primary),
                    ),
                  )
                else
                  _MetricsBody(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricsBody extends StatelessWidget {
  const _MetricsBody({required this.state});

  final StorageState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Text(
          l10n.storageUsed,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatStorageBytes(state.totalBytes),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            Text(
              state.freeDiskBytes > 0
                  ? l10n.storageFree(formatStorageBytes(state.freeDiskBytes))
                  : '',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Stacked bar ─────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (state.totalBytes == 0)
                  Expanded(
                    child: Container(color: AppColors.surfaceContainerHigh),
                  )
                else ...[
                  if (state.dbSizeBytes > 0)
                    Expanded(
                      flex: state.dbSizeBytes,
                      child: Container(color: AppColors.primary),
                    ),
                  if (state.modelSizeBytes > 0)
                    Expanded(
                      flex: state.modelSizeBytes,
                      child: Container(color: _kColorAiModels),
                    ),
                  if (state.chatHistorySizeBytes > 0)
                    Expanded(
                      flex: state.chatHistorySizeBytes,
                      child: Container(color: _kColorChatHistory),
                    ),
                  if (state.mediaSizeBytes > 0)
                    Expanded(
                      flex: state.mediaSizeBytes,
                      child: Container(color: _kColorMedia),
                    ),
                  if (state.otherSizeBytes > 0)
                    Expanded(
                      flex: state.otherSizeBytes,
                      child: Container(color: _kColorOther),
                    ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Legend rows ─────────────────────────────────────────────────────
        _LegendRow(
          color: AppColors.primary,
          label: l10n.storageNoteData,
          value: formatStorageBytes(state.dbSizeBytes),
        ),
        const SizedBox(height: 8),
        _LegendRow(
          color: _kColorAiModels,
          label: l10n.storageAiModels,
          value: formatStorageBytes(state.modelSizeBytes),
        ),
        const SizedBox(height: 8),
        _LegendRow(
          color: _kColorChatHistory,
          label: l10n.storageChatHistory,
          value: formatStorageBytes(state.chatHistorySizeBytes),
        ),
        const SizedBox(height: 8),
        _LegendRow(
          color: _kColorMedia,
          label: l10n.storageMedia,
          value: formatStorageBytes(state.mediaSizeBytes),
        ),
        const SizedBox(height: 8),
        _LegendRow(
          color: _kColorOther,
          label: l10n.storageOther,
          value: formatStorageBytes(state.otherSizeBytes),
        ),
      ],
    );
  }
}

// ── Legend row ────────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Remove data bottom sheet ────────────────────────────────────────────────────

/// Opens the removal options sheet (delete feed notes / delete chat history).
Future<void> showRemoveDataSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final cubit = context.read<StorageCubit>();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.storageRemoveData,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // ── Delete Feed Notes ────────────────────────────────────────
              _SheetOption(
                icon: Icons.article_outlined,
                title: l10n.storageDeleteFeedNotes,
                subtitle: l10n.storageDeleteFeedNotesSubtitle(
                    cubit.state.deletableFeedNoteCount),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = cubit.state.deletableFeedNoteCount;
                  if (count == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.storageNothingToDelete),
                      behavior: SnackBarBehavior.floating,
                    ));
                    return;
                  }
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceContainerLowest,
                      title: Text(
                        l10n.storageDeleteDialogTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      content: Text(
                        l10n.storageDeleteDialogBody(count),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: Text(l10n.actionCancel,
                              style: const TextStyle(
                                  color: AppColors.onSurfaceVariant)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, true),
                          child: Text(
                            l10n.storageDeleteConfirm,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) cubit.deleteFeedNotes();
                },
              ),

              const SizedBox(height: 4),

              // ── Delete Chat History ──────────────────────────────────────
              _SheetOption(
                icon: Icons.chat_bubble_outline_rounded,
                title: l10n.storageDeleteChatHistory,
                subtitle: l10n.storageDeleteChatHistorySubtitle,
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceContainerLowest,
                      title: Text(
                        l10n.storageDeleteChatHistory,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      content: Text(
                        l10n.storageDeleteChatHistoryDialogBody,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: Text(l10n.actionCancel,
                              style: const TextStyle(
                                  color: AppColors.onSurfaceVariant)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, true),
                          child: Text(
                            l10n.storageDeleteConfirm,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) cubit.deleteChatHistory();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ── Bottom sheet option row ───────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.error, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
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
