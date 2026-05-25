import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/shiv/shiv_conversation_entity.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Single row in the Shiv conversation history drawer.
/// Swipe left to delete.
class ShivConversationTile extends StatelessWidget {
  const ShivConversationTile({
    super.key,
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final ShivConversationEntity conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: Key(conversation.conversationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.onError,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 16,
            color:
                isActive ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
        title: Text(
          conversation.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(conversation.updatedAt, l10n),
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        trailing: isActive
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.shivActiveLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              )
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
                size: 18,
              ),
      ),
    );
  }

  String _formatDate(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.shivTimeJustNow;
    if (diff.inHours < 1) return l10n.shivTimeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.shivTimeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.shivTimeDaysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
