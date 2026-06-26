import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// UNIUN floating bottom navigation — the most-touched element in the app.
///
/// Glass pill with three surfaces. Brahma (index 1, create) is a raised FAB in
/// primary blue; Vishnu (0) & Shiv (2) flank it equal-weight. Active side tabs
/// tint to primary with a 3px underline + slight scale — never a heavy fill.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final Future<void> Function(int) onTap;

  // --shadow-nav: blue-tinted lift carried by the pill.
  static const _shadowNav = BoxShadow(
    color: Color(0x24005AB6),
    blurRadius: 32,
    offset: Offset(0, 12),
  );
  // --shadow-primary / --shadow-md: the Brahma FAB rest vs. active elevation.
  static const _shadowMd = BoxShadow(
    color: Color(0x1415181C),
    blurRadius: 12,
    offset: Offset(0, 4),
  );
  static const _shadowPrimary = BoxShadow(
    color: Color(0x3D0075F2),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // Pill height + the distance the FAB is raised above the pill top. The host
  // Stack is sized to pill + lift so the raised FAB stays inside its bounds and
  // fully hittable (no overflow-clipping of taps).
  static const double _pillHeight = 58;
  static const double _fabSize = 56;
  static const double _fabLift = 18;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SizedBox(
            height: _pillHeight + _fabLift,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Glass pill ──────────────────────────────────────────────
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _GlassPill(
                    height: _pillHeight,
                    shadow: _shadowNav,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _NavSide(
                            asset: 'assets/images/tabs/vishnu.svg',
                            label: l10n.navVishnu,
                            selected: currentIndex == 0,
                            onTap: () => onTap(0),
                          ),
                        ),
                        // Reserve the center lane the FAB hovers over.
                        const SizedBox(width: _fabSize),
                        Expanded(
                          child: _NavSide(
                            asset: 'assets/images/tabs/shiva.svg',
                            label: l10n.navShiv,
                            selected: currentIndex == 2,
                            onTap: () => onTap(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Brahma — raised center FAB ──────────────────────────────
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _BrahmaFab(
                      size: _fabSize,
                      label: l10n.navBrahma,
                      selected: currentIndex == 1,
                      shadow: currentIndex == 1 ? _shadowPrimary : _shadowMd,
                      onTap: () => onTap(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The blurred, blue-shadowed pill. Shadow rides on an outer container; the blur
/// is clipped to the pill shape so it only frosts what's behind the bar.
class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.height,
    required this.shadow,
    required this.child,
  });

  final double height;
  final BoxShadow shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [shadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Flanking side tab (Vishnu / Shiv): glyph + uppercase eyebrow label + a 3px
/// underline that appears on the active surface.
class _NavSide extends StatelessWidget {
  const _NavSide({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.neutral400;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 25,
              height: 25,
              child: SvgPicture.asset(
                asset,
                fit: BoxFit.contain,
                theme: SvgTheme(currentColor: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flame-only mark for the Brahma FAB. The tab glyph asset is a filled disc with
/// the flame *cut out*, so tinting it paints a solid circle — here we want just
/// the flame teardrop, fill driven by `currentColor`.
const String _brahmaFlameSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
    'fill="currentColor"><path d="M256 60C256 60 188 220 188 360C188 410 '
    '218 452 256 452C294 452 324 410 324 360C324 220 256 60 256 60Z"/></svg>';

/// Brahma — the always-raised center FAB. Blue disc + white flame at rest; on
/// the active surface it inverts to a white background + primary flame, and
/// deepens its shadow.
class _BrahmaFab extends StatelessWidget {
  const _BrahmaFab({
    required this.size,
    required this.label,
    required this.selected,
    required this.shadow,
    required this.onTap,
  });

  final double size;
  final String label;
  final bool selected;
  final BoxShadow shadow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: label,
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              // White background appears only when Brahma is the active surface.
              color: selected ? AppColors.surface : AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: [shadow],
            ),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: SvgPicture.string(
                  _brahmaFlameSvg,
                  fit: BoxFit.contain,
                  theme: SvgTheme(
                    currentColor:
                        selected ? AppColors.primary : AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
