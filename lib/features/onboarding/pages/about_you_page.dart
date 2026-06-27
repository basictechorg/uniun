import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/onboarding/widgets/field_label.dart';
import 'package:uniun/features/onboarding/widgets/generated_avatar.dart';
import 'package:uniun/features/onboarding/widgets/onboarding_app_bar.dart';

/// Profile setup — shown after key generation on the Create Your Avatar flow.
/// Route args (passed via go_router `extra`): Map{'npub', 'nsec', 'pubkeyHex'}.
class AboutYouPage extends StatefulWidget {
  const AboutYouPage({super.key, this.args});

  final Map? args;

  @override
  State<AboutYouPage> createState() => _AboutYouPageState();
}

// Number of avatar variants the user can shuffle through.
const _kAvatarVariants = 6;

class _AboutYouPageState extends State<AboutYouPage> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _displayNameError;
  String? _usernameError;

  /// Which avatar variant is currently selected (0 = default, 1-5 = shuffled).
  int _avatarVariant = 0;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(() => setState(() {}));
    _usernameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Map _args(BuildContext context) => widget.args ?? {};

  bool get _canContinue =>
      _displayNameController.text.trim().isNotEmpty &&
      _usernameController.text.trim().isNotEmpty;

  /// The seed actually fed into AvatarPlus — pubkeyHex + variant suffix.
  String _avatarSeed(String pubkeyHex) =>
      _avatarVariant == 0 ? pubkeyHex : '${pubkeyHex}_v$_avatarVariant';

  void _shuffle() {
    setState(() => _avatarVariant = (_avatarVariant + 1) % _kAvatarVariants);
  }

  void _onContinue(BuildContext context) {
    final name = _displayNameController.text.trim();
    final username = _usernameController.text.trim();

    final l10n = AppLocalizations.of(context)!;
    bool hasError = false;
    if (name.isEmpty) {
      setState(() => _displayNameError = l10n.aboutYouDisplayNameRequired);
      hasError = true;
    } else {
      setState(() => _displayNameError = null);
    }
    if (username.isEmpty) {
      setState(() => _usernameError = l10n.aboutYouUsernameRequired);
      hasError = true;
    } else {
      setState(() => _usernameError = null);
    }
    if (hasError) return;

    final args = _args(context);
    final pubkeyHex = args['pubkeyHex'] as String? ?? '';
    context.pushNamed(
      AppRoutes.yourIdentityKeys,
      extra: {
        ...args,
        'displayName': name,
        'username': username,
        'bio': _bioController.text.trim(),
        // Only store the variant seed when user shuffled away from default.
        'avatarSeed': _avatarVariant == 0 ? null : _avatarSeed(pubkeyHex),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = _args(context);
    final pubkeyHex = args['pubkeyHex'] as String? ?? '';

    final l10n = AppLocalizations.of(context)!;
    return KeyboardDismissOnTap(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── Ambient brand glow (purely decorative) ──────────────────
            const Positioned.fill(
              child: IgnorePointer(child: _AmbientBackdrop()),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  OnboardingAppBar(onBack: () => Navigator.pop(context)),
                  Expanded(
                    child: SingleChildScrollView(
                      // resizeToAvoidBottomInset already lifts the body above
                      // the keyboard — only add the safe-area gutter here, not
                      // viewInsets.bottom again, or the scroll extent balloons.
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        MediaQuery.of(context).padding.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),

                          // ── Header (eyebrow → title → subtitle) ────────
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.aboutYouEyebrow.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.aboutYouTitle,
                                  // Display serif (--font-display Newsreader) —
                                  // the design system reserves this for
                                  // onboarding headlines. h1 28 · semibold ·
                                  // pinned weight + opsz.
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
                                  l10n.aboutYouSubtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Avatar + shuffle ──────────────────────────
                          GeneratedAvatar(
                            seed: _avatarSeed(pubkeyHex),
                            onShuffle: _shuffle,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.aboutYouAvatarCaption,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Display Name ──────────────────────────────
                          FieldLabel(l10n.aboutYouDisplayNameLabel),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _displayNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: l10n.aboutYouDisplayNameHint,
                              errorText: _displayNameError,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Username ──────────────────────────────────
                          FieldLabel(l10n.aboutYouUsernameLabel),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              hintText: l10n.aboutYouUsernameHint,
                              errorText: _usernameError,
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 20, right: 0),
                                child: Text(
                                  '@',
                                  style: TextStyle(
                                    color: AppColors.outline,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    height: 2.6,
                                  ),
                                ),
                              ),
                              prefixIconConstraints:
                                  const BoxConstraints(minWidth: 0, minHeight: 0),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.aboutYouUsernameHelper,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Bio (optional) ────────────────────────────
                          FieldLabel(l10n.aboutYouBioLabel),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _bioController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: l10n.aboutYouBioHint,
                              alignLabelWithHint: true,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Continue button ───────────────────────────
                          Builder(
                            builder: (ctx) => AnimatedOpacity(
                              opacity: _canContinue ? 1.0 : 0.45,
                              duration: const Duration(milliseconds: 150),
                              child: GestureDetector(
                                onTap: () => _onContinue(ctx),
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primaryContainer,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: _canContinue
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.28),
                                              blurRadius: 24,
                                              offset: const Offset(0, 8),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          l10n.actionContinue,
                                          style: const TextStyle(
                                            color: AppColors.onPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: AppColors.onPrimary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Encrypted reassurance pill ────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_rounded,
                                    size: 13, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.aboutYouEncrypted,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
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
}

/// Two soft brand-blue radial glows bleeding in from opposite corners — the
/// ambient onboarding backdrop. Purely decorative; mirrors the gallery mock.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(top: -120, left: -120, child: _Glow()),
        Positioned(bottom: -140, right: -120, child: _Glow()),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

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
