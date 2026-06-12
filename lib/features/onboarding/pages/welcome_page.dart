import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Welcome / landing screen.
/// No top app bar, no bottom nav — pure onboarding shell.
///
/// Flow:
///   "Create Your Avatar"  → YourIdentityKeysPage (generate a new keypair)
///   "Reclaim Your Avatar" → ImportIdentityPage (import an existing nsec)
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── UNIUN brand ──────────────────────────────────────────
                SvgPicture.asset(
                  'assets/images/uniun-logo.svg',
                  width: 72,
                  height: 72,
                ),
                const SizedBox(height: 12),
                const Text(
                  'UNIUN',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Hero tagline ─────────────────────────────────────────
                _taglineBlock(
                  l10n.welcomeTagline,
                  accent: AppColors.primary,
                  muted: AppColors.onSurfaceVariant,
                  base: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 16),

                // thin accent divider
                Container(
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                const SizedBox(height: 64),

                // ── Primary — Create Your Avatar ─────────────────────────
                _PrimaryButton(
                  onPressed: () {
                    // Generate keypair here so both AboutYou and KeysPage
                    // can receive them as route arguments.
                    final keychain = Keychain.generate();
                    final npub = Nip19.encodePubkey(keychain.public);
                    final nsec = Nip19.encodePrivkey(keychain.private);
                    context.pushNamed(
                      AppRoutes.aboutYou,
                      extra: {
                        'npub': npub,
                        'nsec': nsec,
                        'pubkeyHex': keychain.public,
                      },
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_rounded,
                          color: AppColors.onPrimary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        l10n.welcomeCreateIdentity,
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Secondary — Import existing key ──────────────────────
                _SecondaryButton(
                  onPressed: () =>
                      context.pushNamed(AppRoutes.importIdentity),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.vpn_key_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        l10n.welcomeImportKey,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── Learn more ───────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    // TODO: open how-it-works page
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.welcomeLearnHow,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          color: AppColors.primary, size: 16),
                    ],
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

// ── Button widgets ────────────────────────────────────────────────────────────

/// Solid primary — primary action.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// White card with subtle border — secondary action.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Splits a tagline into colour-coded spans: substrings wrapped in `*asterisks*`
/// render in [accent], everything else in [muted]. Keeps the full phrase in one
/// l10n string while letting the brand verbs stand out.
List<InlineSpan> _taglineSpans(
  String text, {
  required Color accent,
  required Color muted,
}) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*(.+?)\*');
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(
        text: text.substring(cursor, match.start),
        style: TextStyle(color: muted),
      ));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: TextStyle(color: accent),
    ));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(
      TextSpan(text: text.substring(cursor), style: TextStyle(color: muted)),
    );
  }
  return spans;
}

/// Lays out a `left · right` tagline (one such pair per `\n` line) as a column
/// of full-width rows. Each row splits into two equal-flex halves with the `·`
/// between them, so every dot lands on the page's centre line and the dots
/// align vertically. Left words hug the dot from the right, right words from
/// the left. Words wrapped in *asterisks* render in [accent]; separators in
/// [muted].
Widget _taglineBlock(
  String raw, {
  required Color accent,
  required Color muted,
  required TextStyle base,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final line in raw.split('\n'))
        _taglineRow(line, accent: accent, muted: muted, base: base),
    ],
  );
}

Widget _taglineRow(
  String line, {
  required Color accent,
  required Color muted,
  required TextStyle base,
}) {
  final parts = line.split(' · ');
  final left = parts.first;
  final right = parts.length > 1 ? parts[1] : '';

  Widget half(String text, Alignment alignment) => Expanded(
        child: Align(
          alignment: alignment,
          child: Text.rich(
            TextSpan(
              children: _taglineSpans(text, accent: accent, muted: muted),
            ),
            style: base,
          ),
        ),
      );

  return Row(
    children: [
      half(left, Alignment.centerRight),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('·', style: base.copyWith(color: muted)),
      ),
      half(right, Alignment.centerLeft),
    ],
  );
}
