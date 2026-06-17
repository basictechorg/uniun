import 'package:flutter/material.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Centered "Join or Create" chooser — used by both public and private channel
/// flows so the entry experience is consistent.
class ChannelEntryChooser extends StatelessWidget {
  const ChannelEntryChooser({
    super.key,
    required this.title,
    required this.subtitle,
    required this.joinLabel,
    required this.createLabel,
    required this.onJoin,
    required this.onCreate,
    this.icon = Icons.tag_rounded,
  });

  final String title;
  final String subtitle;
  final String joinLabel;
  final String createLabel;
  final VoidCallback onJoin;
  final VoidCallback onCreate;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: UniunBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              _EntryCard(
                icon: Icons.login_rounded,
                label: joinLabel,
                onTap: onJoin,
                filled: true,
              ),
              const SizedBox(height: 16),
              _EntryCard(
                icon: Icons.add_rounded,
                label: createLabel,
                onTap: onCreate,
                filled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : Colors.transparent;
    final fg = filled ? AppColors.onPrimary : AppColors.primary;
    final border = filled
        ? const Border.fromBorderSide(BorderSide.none)
        : Border.all(color: AppColors.primary, width: 1.4);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: fg),
          ],
        ),
      ),
    );
  }
}
