import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/common/widgets/drop_icon.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// "Learn how UNIUN works" — a simple, swipeable intro carousel reached from the
/// Welcome screen's learn-more link.
///
/// Six friendly slides (second brain → the three modules → knowledge graph →
/// your keys → offline & private → get started). Skip and the final "Get
/// started" both [context.pop] back to Welcome, so the keypair-generation path
/// stays solely on the Welcome screen.
class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key});

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() => _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

  /// Close the carousel. Normally it was pushed from Welcome, so we pop back;
  /// if it happens to be the root route (nothing to pop), go to Welcome.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final slides = <_Slide>[
      _Slide(
        hero: const _LogoHero(),
        title: l10n.howItWorksIntroTitle,
        body: l10n.howItWorksIntroBody,
      ),
      _Slide(
        hero: const _DeityHero(asset: 'assets/images/tabs/brahma.svg'),
        title: l10n.howItWorksBrahmaTitle,
        body: l10n.howItWorksBrahmaBody,
        features: [
          _Feature(
            icon: const Icon(Icons.edit_note_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileNote,
            desc: l10n.howItWorksDescNote,
          ),
          _Feature(
            icon: const Icon(Icons.man_3_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileManas,
            desc: l10n.howItWorksDescManas,
          ),
          _Feature(
            icon: const Icon(Icons.hub_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileGraph,
            desc: l10n.howItWorksDescGraph,
          ),
        ],
      ),
      _Slide(
        hero: const _DeityHero(asset: 'assets/images/tabs/vishnu.svg'),
        title: l10n.howItWorksVishnuTitle,
        body: l10n.howItWorksVishnuBody,
        features: [
          _Feature(
            icon: const Icon(Icons.person_outline_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTilePeople,
            desc: l10n.howItWorksDescPeople,
          ),
          _Feature(
            icon: const Icon(Icons.tag_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileChannels,
            desc: l10n.howItWorksDescChannels,
          ),
          _Feature(
            icon: const Icon(Icons.lock_outline_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTilePrivate,
            desc: l10n.howItWorksDescPrivate,
          ),
          _Feature(
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileDms,
            desc: l10n.howItWorksDescDms,
          ),
        ],
      ),
      _Slide(
        hero: const _DeityHero(asset: 'assets/images/tabs/shiva.svg'),
        title: l10n.howItWorksShivTitle,
        body: l10n.howItWorksShivBody,
        features: [
          _Feature(
            icon: const DropIcon(size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileAdiyogi,
            desc: l10n.howItWorksDescAdiyogi,
          ),
          _Feature(
            icon: const Icon(
              Icons.sports_gymnastics_rounded,
              size: 24,
              color: AppColors.primary,
            ),
            name: l10n.howItWorksTileNataraj,
            desc: l10n.howItWorksDescNataraj,
          ),
          _Feature(
            icon: const Icon(Icons.smart_toy_rounded,
                size: 24, color: AppColors.primary),
            name: l10n.howItWorksTileGana,
            desc: l10n.howItWorksDescGana,
          ),
        ],
      ),
      _Slide(
        hero: const _GlowHero(icon: Icons.vpn_key_rounded),
        title: l10n.howItWorksKeysTitle,
        body: l10n.howItWorksKeysBody,
      ),
      _Slide(
        hero: const _GlowHero(icon: Icons.cloud_off_rounded),
        title: l10n.howItWorksPrivateTitle,
        body: l10n.howItWorksPrivateBody,
      ),
      _Slide(
        hero: const _GlowHero(icon: Icons.auto_awesome_rounded),
        title: l10n.howItWorksReadyTitle,
        body: l10n.howItWorksReadyBody,
      ),
    ];
    final isLast = _index == slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip (hidden + inert on the last slide) ──────────────────
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast ? null : () => _close(context),
                    child: Text(
                      l10n.howItWorksSkip,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Slides ───────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: slides[i]),
              ),
            ),

            const SizedBox(height: 8),
            _Dots(count: slides.length, index: _index),
            const SizedBox(height: 24),

            // ── Next / Get started ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: _PrimaryButton(
                onPressed: () => isLast ? _close(context) : _next(),
                label: isLast ? l10n.howItWorksGetStarted : l10n.howItWorksNext,
                showArrow: !isLast,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide data ────────────────────────────────────────────────────────────────

class _Slide {
  const _Slide({
    required this.hero,
    required this.title,
    this.body,
    this.features,
  });

  final Widget hero;
  final String title;

  /// Short lead under the title. Optional.
  final String? body;

  /// Per-sub-feature sections (icon + name + description). Pillar slides only.
  final List<_Feature>? features;
}

/// One sub-feature row: its real in-app icon, its name, and a short description.
class _Feature {
  const _Feature({required this.icon, required this.name, required this.desc});

  final Widget icon;
  final String name;
  final String desc;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    // Scrollable + min-height so content centres on tall screens and never
    // overflows on short ones.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                slide.hero,
                SizedBox(height: slide.features == null ? 40 : 28),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                if (slide.body != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    slide.body!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
                if (slide.features != null) ...[
                  const SizedBox(height: 24),
                  for (final f in slide.features!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _FeatureRow(feature: f),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Heroes ────────────────────────────────────────────────────────────────────

/// Soft radial brand glow — shared backdrop for every hero.
class _GlowCircle extends StatelessWidget {
  const _GlowCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primaryContainer.withValues(alpha: 0.06),
            AppColors.primary.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 0.75],
        ),
      ),
    );
  }
}

/// Logo over the brand glow with the gradient UNIUN wordmark — the intro hero.
class _LogoHero extends StatelessWidget {
  const _LogoHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const _GlowCircle(),
              SvgPicture.asset(
                'assets/images/uniun-logo-mark.svg',
                width: 96,
                height: 96,
              ),
            ],
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryContainer],
          ).createShader(bounds),
          child: const Text(
            'UNIUN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single Material glyph in a tinted disc over the brand glow.
class _GlowHero extends StatelessWidget {
  const _GlowHero({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _GlowCircle(),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Icon(icon, size: 50, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// A pillar hero: the module's large tab glyph (Brahma / Vishnu / Shiv — the
/// same bottom-nav icon) inside a tinted disc over the brand glow, so the user
/// learns to recognise the tab inside the app.
class _DeityHero extends StatelessWidget {
  const _DeityHero({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _GlowCircle(),
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Center(
              child: SvgPicture.asset(
                asset,
                width: 72,
                height: 72,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One sub-feature section: an app-style rounded icon tile (the exact icon the
/// feature shows elsewhere in the app), its name, and a short description.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(child: feature.icon),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                feature.name,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                feature.desc,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Page dots ─────────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Bottom button ─────────────────────────────────────────────────────────────

/// Gradient primary — mirrors the Welcome screen's primary button idiom.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onPressed,
    required this.label,
    required this.showArrow,
  });

  final VoidCallback onPressed;
  final String label;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showArrow) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.onPrimary, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
