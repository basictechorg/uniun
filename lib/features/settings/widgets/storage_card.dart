import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';

const _kColorAiModels = Color(0xFF4CAF50);
const _kColorChatHistory = Color(0xFFFF9800);
const _kColorMedia = Color(0xFF03A9F4);
const _kColorOther = Color(0xFF9E9E9E);

class StorageCard extends StatelessWidget {
  const StorageCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StorageCubit, StorageState>(
      listener: (context, state) {
        if (state.deleteSuccess) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.storageDeleteSuccess(state.deletedCount)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ));
        }
        if (state.deleteChatHistorySuccess) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.storageDeleteChatHistorySuccess),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ));
        }
        if (state.deleteError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.deleteError!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        String fmtBytes(int bytes) {
          final mb = bytes / (1024 * 1024);
          if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
          if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
          return '${(bytes / 1024).toStringAsFixed(0)} KB';
        }

        final totalLabel = fmtBytes(state.totalBytes);
        final dbLabel = fmtBytes(state.dbSizeBytes);
        final modelLabel = fmtBytes(state.modelSizeBytes);
        final chatLabel = fmtBytes(state.chatHistorySizeBytes);
        final mediaLabel = fmtBytes(state.mediaSizeBytes);
        final otherLabel = fmtBytes(state.otherSizeBytes);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: state.isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    const Text(
                      'Used',
                      style: TextStyle(
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
                          totalLabel,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          state.freeDiskBytes > 0
                              ? '${fmtBytes(state.freeDiskBytes)} free'
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

                    // ── Stacked bar ──────────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            if (state.totalBytes == 0)
                              Expanded(
                                child: Container(
                                    color: AppColors.surfaceContainerHigh),
                              )
                            else ...[
                              if (state.dbSizeBytes > 0)
                                Expanded(
                                  flex: state.dbSizeBytes,
                                  child:
                                      Container(color: AppColors.primary),
                                ),
                              if (state.modelSizeBytes > 0)
                                Expanded(
                                  flex: state.modelSizeBytes,
                                  child: Container(color: _kColorAiModels),
                                ),
                              if (state.chatHistorySizeBytes > 0)
                                Expanded(
                                  flex: state.chatHistorySizeBytes,
                                  child:
                                      Container(color: _kColorChatHistory),
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

                    // ── Legend rows ──────────────────────────────────────────
                    _LegendRow(
                      color: AppColors.primary,
                      label: l10n.storageNoteData,
                      value: dbLabel,
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      color: _kColorAiModels,
                      label: l10n.storageAiModels,
                      value: modelLabel,
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      color: _kColorChatHistory,
                      label: l10n.storageChatHistory,
                      value: chatLabel,
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      color: _kColorMedia,
                      label: l10n.storageMedia,
                      value: mediaLabel,
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      color: _kColorOther,
                      label: l10n.storageOther,
                      value: otherLabel,
                    ),

                    const SizedBox(height: 8),
                    const Divider(color: AppColors.outlineVariant, height: 1),
                    const SizedBox(height: 16),

                    // ── Remove data button ───────────────────────────────────
                    _RemoveDataButton(state: state),
                  ],
                ),
        );
      },
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

// ── Remove data button ────────────────────────────────────────────────────────

class _RemoveDataButton extends StatelessWidget {
  const _RemoveDataButton({required this.state});

  final StorageState state;

  Future<void> _showOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<StorageCubit>();

    await showModalBottomSheet<void>(
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

                // ── Delete Feed Notes ────────────────────────────────────
                _SheetOption(
                  icon: Icons.article_outlined,
                  title: l10n.storageDeleteFeedNotes,
                  subtitle: l10n.storageDeleteFeedNotesSubtitle(
                      state.deletableFeedNoteCount),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final count = state.deletableFeedNoteCount;
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
                            child: const Text('Cancel',
                                style: TextStyle(
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

                // ── Delete Chat History ──────────────────────────────────
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
                            child: const Text('Cancel',
                                style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = state.isDeleting || state.isDeletingChatHistory;

    return GestureDetector(
      onTap: busy ? null : () => _showOptions(context),
      child: Row(
        children: [
          busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.error,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Text(
            l10n.storageRemoveData,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
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
