import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/features/onboarding/interests/onboarding_interest.dart';
import 'package:uniun/features/onboarding/widgets/onboarding_app_bar.dart';
import 'package:uniun/l10n/app_localizations.dart';

// Chip metrics — shared by the width measurer and the chip widget so the
// computed grid positions match what's actually rendered.
const double _kChipFont = 14.5;
const double _kChipAvatar = 26;
const double _kChipGap = 9; // avatar → label gap
const double _kChipPadL = 9;
const double _kChipPadR = 16;
const double _kChipVPad = 9;
const double _kChipHeight = _kChipAvatar + _kChipVPad * 2;

/// Onboarding step shown right after the user's keys are saved.
///
/// The user taps a few interests; each one follows a house account (see
/// [kOnboardingInterests]) so the Vishnu feed isn't empty on first launch.
/// At least [_minSelection] picks are required before continuing.
///
/// The chips sit on a canvas wider than the screen — the user drags freely in
/// any direction (via [InteractiveViewer]) and chips gently grow toward the
/// centre. A search box filters the chips. Chips are packed by their measured
/// width with an even gap, so short and long names sit equally close.
class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  static const int _minSelection = 3;

  // staggered-grid geometry
  static const double _startX = 44;
  static const double _startY = 48;
  static const double _rowStep = 76; // chip height (44) + ~32 vertical gap
  static const double _colGap = 24; // gap between chips in a row
  static const double _oddOffset = 52;

  final TransformationController _tc = TransformationController();
  final TextEditingController _searchCtrl = TextEditingController();

  final Set<String> _selected = <String>{};
  String _query = '';
  bool _saving = false;
  String _centerSig = '';

  @override
  void dispose() {
    _tc.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OnboardingInterest> get _filtered {
    if (_query.isEmpty) return kOnboardingInterests;
    final q = _query.toLowerCase();
    return kOnboardingInterests
        .where((i) => i.name.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String pubkey) {
    setState(() {
      if (!_selected.remove(pubkey)) _selected.add(pubkey);
    });
  }

  Future<void> _continue() async {
    if (_selected.length < _minSelection || _saving) return;
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final result =
        await getIt<FollowUsersUseCase>().call(_selected.toList());
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.interestsFollowFailed)),
        );
      },
      (_) => router.goNamed(AppRoutes.home),
    );
  }

  void _skip() => GoRouter.of(context).goNamed(AppRoutes.home);

  /// Width of a chip given its label — must mirror [_InterestChip]'s layout.
  double _chipWidth(String name, BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: _kChipFont,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return _kChipPadL + _kChipAvatar + _kChipGap + tp.width + _kChipPadR;
  }

  // ── staggered placement: rows of 4 / 3 (odd offset), packed by chip width ──
  List<_Placed> _place(List<OnboardingInterest> items, BuildContext context) {
    final out = <_Placed>[];
    int i = 0, row = 0;
    while (i < items.length) {
      final even = row.isEven;
      final len = math.min(even ? 4 : 3, items.length - i);
      double x = _startX + (even ? 0 : _oddOffset);
      final y = _startY + row * _rowStep;
      for (int c = 0; c < len; c++) {
        final item = items[i + c];
        final w = _chipWidth(item.name, context);
        out.add(_Placed(item, x + w / 2, y, w)); // store the centre x
        x += w + _colGap;
      }
      i += len;
      row++;
    }
    return out;
  }

  /// Re-centre the canvas in the viewport whenever its content size changes
  /// (first build + after a search filter). User panning never triggers this.
  void _maybeCenter(double vpW, double vpH, double cw, double ch) {
    final sig = '$vpW:$vpH:$cw:$ch';
    if (_centerSig == sig) return;
    _centerSig = sig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tc.value = Matrix4.translationValues((vpW - cw) / 2, (vpH - ch) / 2, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final n = _selected.length;
    final canContinue = n >= _minSelection && !_saving;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingAppBar(onBack: () => Navigator.pop(context)),

            // ── header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.interestsEyebrow.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.interestsTitle,
                    style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontVariations: [FontVariation('wght', 600)],
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: -0.5,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.interestsSubtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // ── search ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: _SearchBar(
                controller: _searchCtrl,
                hint: l10n.interestsSearchHint,
                onChanged: (v) => setState(() => _query = v.trim()),
                onClear: () => setState(() {
                  _searchCtrl.clear();
                  _query = '';
                }),
              ),
            ),

            // ── draggable chip field ────────────────────────────────────────
            Expanded(child: _buildField(l10n)),

            // ── footer ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: canContinue ? _continue : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: canContinue
                            ? AppColors.primary
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: canContinue
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.24),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                n >= _minSelection
                                    ? l10n.interestsContinue
                                    : l10n.interestsPickMore(_minSelection - n),
                                style: TextStyle(
                                  color: canContinue
                                      ? AppColors.onPrimary
                                      : AppColors.outline,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text(
                      l10n.interestsSkip,
                      style: const TextStyle(
                        color: AppColors.outline,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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

  Widget _buildField(AppLocalizations l10n) {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n.interestsNoResults,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }

    final placed = _place(items, context);
    final contentW =
        placed.fold<double>(0, (m, p) => math.max(m, p.dx + p.w / 2)) + 40;
    final contentH =
        placed.fold<double>(0, (m, p) => math.max(m, p.dy)) +
            _kChipHeight / 2 +
            40;

    // Chip content widgets are built here (not inside the AnimatedBuilder), so a
    // pan only re-wraps them in Transform/Opacity — the avatars never rebuild.
    final chips = [
      for (final p in placed)
        _InterestChip(
          name: p.item.name,
          pubkeyHex: p.item.pubkeyHex,
          selected: _selected.contains(p.item.pubkeyHex),
          onTap: () => _toggle(p.item.pubkeyHex),
        ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final vpW = c.maxWidth, vpH = c.maxHeight;
        _maybeCenter(vpW, vpH, contentW, contentH);
        return ClipRect(
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                scaleEnabled: false,
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(160),
                child: SizedBox(
                  width: contentW,
                  height: contentH,
                  child: AnimatedBuilder(
                    animation: _tc,
                    builder: (context, _) {
                      final center = _tc.toScene(Offset(vpW / 2, vpH / 2));
                      final reach = math.min(vpW, vpH) * 0.95;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < placed.length; i++)
                            _wrap(placed[i], chips[i], center, reach),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // edge fades hint there's more to scroll into
              const _EdgeFade(Alignment.centerLeft),
              const _EdgeFade(Alignment.centerRight),
              const _EdgeFade(Alignment.topCenter),
              const _EdgeFade(Alignment.bottomCenter),
            ],
          ),
        );
      },
    );
  }

  /// Positions a chip centred on its grid point and applies a gentle fish-eye
  /// (grow toward the viewport centre, ease off + fade at the edges).
  Widget _wrap(_Placed p, Widget chip, Offset center, double reach) {
    final dist = (Offset(p.dx, p.dy) - center).distance;
    final norm = math.min(1.0, dist / reach);
    final scale = 1.05 - norm * 0.24;
    final opacity = math.max(0.55, 1 - norm * 0.35);
    return Positioned(
      left: p.dx,
      top: p.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: chip),
        ),
      ),
    );
  }
}

class _Placed {
  const _Placed(this.item, this.dx, this.dy, this.w);
  final OnboardingInterest item;
  final double dx; // centre x
  final double dy; // centre y
  final double w; // measured chip width
}

// ── chip ───────────────────────────────────────────────────────────────────

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.name,
    required this.pubkeyHex,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String pubkeyHex;
  final bool selected;
  final VoidCallback onTap;

  static const _unselected = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEEF5FF), Color(0xFFDCECFF)],
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(
            _kChipPadL, _kChipVPad, _kChipPadR, _kChipVPad),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryContainer],
                )
              : _unselected,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(seed: pubkeyHex, size: _kChipAvatar),
            const SizedBox(width: _kChipGap),
            Text(
              name,
              style: TextStyle(
                fontSize: _kChipFont,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded,
                  size: 17, color: AppColors.onPrimary),
            ],
          ],
        ),
      ),
    );
  }
}

// ── search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 20, color: AppColors.outline),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.outline),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── decorative edge fade ─────────────────────────────────────────────────────

class _EdgeFade extends StatelessWidget {
  const _EdgeFade(this.align);
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    final horizontal =
        align == Alignment.centerLeft || align == Alignment.centerRight;
    return Align(
      alignment: align,
      child: IgnorePointer(
        child: Container(
          width: horizontal ? 28 : double.infinity,
          height: horizontal ? double.infinity : 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _begin(align),
              end: _end(align),
              colors: [
                AppColors.surface,
                AppColors.surface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Alignment _begin(Alignment a) {
    if (a == Alignment.centerLeft) return Alignment.centerLeft;
    if (a == Alignment.centerRight) return Alignment.centerRight;
    if (a == Alignment.topCenter) return Alignment.topCenter;
    return Alignment.bottomCenter;
  }

  Alignment _end(Alignment a) {
    if (a == Alignment.centerLeft) return Alignment.centerRight;
    if (a == Alignment.centerRight) return Alignment.centerLeft;
    if (a == Alignment.topCenter) return Alignment.bottomCenter;
    return Alignment.topCenter;
  }
}
