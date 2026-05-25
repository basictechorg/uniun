import 'package:flutter/material.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/core/theme/app_theme.dart';

enum _ThemeChoice { system, light, dark }

class StyleCard extends StatefulWidget {
  const StyleCard({super.key});

  @override
  State<StyleCard> createState() => _StyleCardState();
}

class _StyleCardState extends State<StyleCard> {
  // UI-only state for now. Wiring to MaterialApp.themeMode + persistence
  // comes in a follow-up once the palette refactor is done.
  _ThemeChoice _choice = _ThemeChoice.system;

  String _label(AppLocalizations l10n) => switch (_choice) {
        _ThemeChoice.system => l10n.styleThemeSystem,
        _ThemeChoice.light => l10n.styleThemeLight,
        _ThemeChoice.dark => l10n.styleThemeDark,
      };

  IconData get _icon => switch (_choice) {
        _ThemeChoice.system => Icons.brightness_auto_rounded,
        _ThemeChoice.light => Icons.light_mode_rounded,
        _ThemeChoice.dark => Icons.dark_mode_rounded,
      };

  void _cycle() {
    setState(() {
      _choice = _ThemeChoice.values[
          (_choice.index + 1) % _ThemeChoice.values.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _cycle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.styleTheme,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Icon(_icon,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    _label(l10n),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 20,
            color: AppColors.surfaceContainer.withValues(alpha: 0.5),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.styleAccent,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const Text(
                '#319BED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfaceContainer,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
