import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/onboarding/widgets/key_qr_scanner_page.dart';
import 'package:uniun/features/onboarding/widgets/onboarding_app_bar.dart';
import 'package:uniun/features/onboarding/widgets/terms_checkbox.dart';

/// Login screen — "Reclaim Your Avatar".
class ImportIdentityPage extends StatefulWidget {
  const ImportIdentityPage({super.key});

  @override
  State<ImportIdentityPage> createState() => _ImportIdentityPageState();
}

class _ImportIdentityPageState extends State<ImportIdentityPage> {
  final _controller = TextEditingController();
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _controller.text.trim().isNotEmpty && _termsAccepted;

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _controller.text = data!.text!);
    }
  }

  /// Opens the camera scanner and, on success, fills the key field with the
  /// scanned value — identical downstream handling to a clipboard paste.
  Future<void> _scanQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const KeyQrScannerPage()),
    );
    if (!mounted) return;
    final value = scanned?.trim();
    if (value != null && value.isNotEmpty) {
      setState(() => _controller.text = value);
    }
  }

  Future<void> _onContinue() async {
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.of(context);
    final input = _controller.text.trim();
    if (input.isEmpty) {
      _showError(l10n.importPasteFirst);
      return;
    }

    try {
      final String hexPriv;
      if (input.startsWith('nsec1')) {
        hexPriv = Nip19.decodePrivkey(input);
        if (hexPriv.isEmpty) throw Exception('Invalid nsec');
      } else if (input.length == 64) {
        hexPriv = input;
      } else {
        throw Exception('Unrecognised key format');
      }

      final result = await getIt<ImportKeyUseCase>().call(input);
      if (!mounted) return;
      await result.fold(
        (failure) async => _showError(l10n.importFailed),
        (user) async {
          await _addImportedPubkeyToMissingList(user.pubkeyHex);
          if (!mounted) return;
          router.goNamed(AppRoutes.home);
        },
      );
      return;
    } catch (_) {
      _showError(l10n.importInvalidKey);
    }
  }

  Future<void> _addImportedPubkeyToMissingList(String pubkeyHex) async {
    if (pubkeyHex.isEmpty) return;
    final isar = getIt<Isar>();
    try {
      final profile = await isar.profileModels.where().pubkeyEqualTo(pubkeyHex).findFirst();
      if (profile != null) return;

      await isar.writeTxn(() async {
        final existing = await isar.missingProfilePubkeyModels
            .where()
            .pubkeyEqualTo(pubkeyHex)
            .findFirst();
        if (existing != null) return;

        final row = MissingProfilePubkeyModel()
          ..pubkey = pubkeyHex
          ..firstSeenAt = DateTime.now();
        await isar.missingProfilePubkeyModels.put(row);
      });
    } catch (_) {
      // Best-effort only. Import should succeed even if this tracking fails.
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return KeyboardDismissOnTap(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: _AmbientGlow()),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OnboardingAppBar(onBack: () => Navigator.pop(context)),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Eyebrow ───────────────────────────────────
                          Text(
                            l10n.importEyebrow.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            l10n.importTitle,
                            // Display serif (--font-display Newsreader) — the
                            // design system reserves this for onboarding
                            // headlines. h1 28 · semibold · pinned weight + opsz.
                            style: const TextStyle(
                              fontFamily: 'Newsreader',
                              fontVariations: [
                                FontVariation('wght', 600),
                                FontVariation('opsz', 28),
                              ],
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: -0.56,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.importSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.importPrivateKeyLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              GestureDetector(
                                onTap: _pasteFromClipboard,
                                child: Row(
                                  children: [
                                    const Icon(Icons.content_paste_rounded,
                                        size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.importPasteFromClipboard,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          TextField(
                            controller: _controller,
                            maxLines: 4,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.importKeyHint,
                              fillColor: AppColors.surfaceContainerLow,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Scan a QR instead (secondary) ─────────────
                          GestureDetector(
                            onTap: _scanQr,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.outlineVariant
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_scanner_rounded,
                                      size: 20, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.importScanQrButton,
                                    style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lock_rounded,
                                    color: AppColors.primary, size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.importSecurityNote,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom-pinned terms + primary CTA ─────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TermsCheckbox(
                          accepted: _termsAccepted,
                          onChanged: (v) =>
                              setState(() => _termsAccepted = v),
                          onOpenTerms: () => context.pushNamed(
                            AppRoutes.privacyPolicy,
                            extra: true,
                          ),
                          onOpenPrivacy: () =>
                              context.pushNamed(AppRoutes.privacyPolicy),
                        ),
                        const SizedBox(height: 12),
                        AnimatedOpacity(
                          opacity: _canContinue ? 1.0 : 0.45,
                          duration: const Duration(milliseconds: 150),
                          child: GestureDetector(
                            onTap: _canContinue ? _onContinue : null,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _canContinue
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.22),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  l10n.importContinue,
                                  style: const TextStyle(
                                    color: AppColors.onPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// Two soft brand-blue corner glows behind the onboarding content — pure
/// decoration, mirrors the welcome screen's radial-glow vocabulary.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(top: -120, left: -120, child: _GlowBlob()),
        Positioned(bottom: -120, right: -120, child: _GlowBlob()),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
