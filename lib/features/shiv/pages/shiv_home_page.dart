import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_history_drawer.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Shiv landing / home — the hero "ask Shiv" screen.
///
/// Pure presentation: the parent ([_ShivRoot]) supplies the behaviour.
/// - [onAsk]         → start a fresh conversation (the tab swaps to the chat).
/// - [onSuggest]     → start a conversation seeded with a suggested prompt.
/// - [onOpenGana]    → push the Gana page.
/// - [onOpenNataraj] → push the Nataraj deck.
/// - [onDrawerChanged] lets [ShivPage] hide the FloatingNav while the history
///   drawer is open (same pattern as [ShivChatPage]).
class ShivHomePage extends StatelessWidget {
  const ShivHomePage({
    super.key,
    required this.onAsk,
    required this.onSuggest,
    required this.onOpenGana,
    required this.onOpenNataraj,
    required this.onDrawerChanged,
  });

  final VoidCallback onAsk;
  final ValueChanged<String> onSuggest;
  final VoidCallback onOpenGana;
  final VoidCallback onOpenNataraj;
  final ValueChanged<bool> onDrawerChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suggestions = <String>[
      l10n.shivHomeSuggestSummarize,
      l10n.shivHomeSuggestConnect,
      l10n.shivHomeSuggestDraft,
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      drawer: const ShivHistoryDrawer(),
      onDrawerChanged: onDrawerChanged,
      // Builder gives a context below this Scaffold so openDrawer() resolves.
      body: Builder(
        builder: (ctx) => SafeArea(
          child: Column(
            children: [
              _HomeAppBar(onMenu: () => Scaffold.of(ctx).openDrawer()),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _HeroLogo(),
                            const SizedBox(height: 18),
                            Text(
                              l10n.shivHomeHeadline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _AskCard(hint: l10n.shivInputHint, onTap: onAsk),
                            const SizedBox(height: 14),
                            _Suggestions(items: suggestions, onTap: onSuggest),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: _ToolButton(
                                    icon: Icons.auto_mode_rounded,
                                    label: l10n.shivHomeGana,
                                    onTap: onOpenGana,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ToolButton(
                                    icon: Icons.cyclone_rounded,
                                    label: l10n.shivHomeNataraj,
                                    onTap: onOpenNataraj,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App bar ──────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 6),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMenu,
            child: SvgPicture.asset(
              'assets/images/tabs/shiva.svg',
              width: 28,
              height: 28,
              colorFilter: const ColorFilter.mode(
                AppColors.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onMenu,
            tooltip: l10n.shivHomeHistoryTooltip,
            icon: const Icon(
              Icons.history_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero logo ────────────────────────────────────────────────────────────────

class _HeroLogo extends StatelessWidget {
  const _HeroLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/images/tabs/shiva.svg',
        width: 36,
        height: 36,
        colorFilter: const ColorFilter.mode(
          AppColors.primary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

// ── Ask card ─────────────────────────────────────────────────────────────────

class _AskCard extends StatelessWidget {
  const _AskCard({required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 18,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_upward_rounded,
              color: AppColors.onPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion chips ─────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.items, required this.onTap});
  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final s in items)
          Material(
            color: AppColors.surface,
            shape: const StadiumBorder(
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onTap(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tool buttons (Gana · Nataraj) ────────────────────────────────────────────

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared white card (border + soft shadow + ripple) ────────────────────────

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    required this.onTap,
    required this.radius,
    required this.padding,
  });
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: br,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
