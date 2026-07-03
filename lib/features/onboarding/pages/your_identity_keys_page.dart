import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/features/onboarding/widgets/key_card.dart';
import 'package:uniun/features/onboarding/widgets/onboarding_app_bar.dart';
import 'package:uniun/features/onboarding/widgets/terms_checkbox.dart';

/// Shows the generated npub + nsec after profile setup.
/// Route args: Map{'npub': String, 'nsec': String}
///
/// The user can Save & Continue as soon as Terms are accepted. If they haven't
/// copied the private key yet, a confirmation dialog warns that losing the key
/// means losing the account forever before proceeding.
class YourIdentityKeysPage extends StatefulWidget {
  const YourIdentityKeysPage({super.key, this.args});

  final Map? args;

  @override
  State<YourIdentityKeysPage> createState() => _YourIdentityKeysPageState();
}

class _YourIdentityKeysPageState extends State<YourIdentityKeysPage> {
  bool _pubKeyCopied = false;
  bool _privKeyCopied = false;
  bool _nsecVisible = false;
  bool _termsAccepted = false;

  Future<void> _saveAndContinue(BuildContext context, Map args, String nsec) async {
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await getIt<ImportKeyUseCase>().call(nsec);
    if (!mounted) return;
    await result.fold(
      (failure) async => messenger.showSnackBar(
        SnackBar(content: Text(l10n.keysFailedToSave(failure.toMessage()))),
      ),
      (user) async {
        // Save profile data collected in AboutYouPage
        final displayName = args['displayName'] as String? ?? '';
        final username = args['username'] as String? ?? '';
        final bio = args['bio'] as String? ?? '';
        // avatarSeed is only set when user shuffled away from the default.
        // Store as 'generated:<seed>' so UserAvatar can detect and use it.
        final avatarSeed = args['avatarSeed'] as String?;
        final avatarUrl = avatarSeed != null ? 'generated:$avatarSeed' : null;
        if (displayName.isNotEmpty || username.isNotEmpty) {
          final profile = ProfileEntity(
            pubkey: user.pubkeyHex,
            name: displayName.isEmpty ? null : displayName,
            username: username.isEmpty ? null : username,
            about: bio.isEmpty ? null : bio,
            avatarUrl: avatarUrl,
            updatedAt: DateTime.now(),
            lastSeenAt: DateTime(3000, 6, 1),
          );
          await getIt<SaveProfileUseCase>().call(profile);
          await _enqueueKind0MetadataEvent(user.nsec, profile);
        }
        if (!mounted) return;
        // New users land on the interest picker (follow a few house accounts so
        // the feed isn't empty) before reaching home.
        router.goNamed(AppRoutes.interests);
      },
    );
  }

  Future<void> _enqueueKind0MetadataEvent(String nsec, ProfileEntity profile) async {
    final privkeyHex = nsec.startsWith('nsec1') ? Nip19.decodePrivkey(nsec) : nsec;
    if (privkeyHex.isEmpty) return;

    final metadata = <String, dynamic>{
      if (profile.name != null) 'display_name': profile.name,
      if (profile.username != null) 'name': profile.username,
      if (profile.about != null) 'about': profile.about,
      if (profile.avatarUrl != null) 'picture': profile.avatarUrl,
      if (profile.nip05 != null) 'nip05': profile.nip05,
    };

    final event = Event.from(
      privkey: privkeyHex,
      kind: 0,
      content: jsonEncode(metadata),
      tags: const [],
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    await getIt<EventQueueRepository>().enqueueSignedEvent(
      eventId: event.id,
      authorPubkey: event.pubkey,
      sig: event.sig,
      kind: 0,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      content: event.content,
      created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }

  void _copyPub(String value) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: value));
    setState(() => _pubKeyCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.keysPublicCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyPriv(String value) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: value));
    setState(() => _privKeyCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.keysPrivateCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args ?? {};
    final npub = args['npub'] as String? ?? 'npub1...';
    final nsec = args['nsec'] as String? ?? 'nsec1...';
    final canContinue = _termsAccepted;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // ambient blue blobs (purely decorative)
          const Positioned(top: -70, left: -90, child: _AmbientBlob()),
          const Positioned(bottom: -60, right: -90, child: _AmbientBlob()),
          SafeArea(
            child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final topGap = h < 680 ? 8.0 : 16.0;
              final midGap = h < 680 ? 8.0 : 12.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OnboardingAppBar(onBack: () => Navigator.pop(context)),

                  // ── Keys + warning — pinned to the top, scrolls if tight ─
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: topGap),

                            // eyebrow
                            Text(
                              l10n.keysEyebrow.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // serif display headline
                            Text(
                              l10n.keysHeadline,
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontVariations: [FontVariation('wght', 600)],
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                letterSpacing: -0.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),

                            SizedBox(height: midGap + 12),

                            KeyCard(
                              label: l10n.keysPublicKeyTitle,
                              helper: l10n.keysPublicKeySubtitle,
                              keyValue: npub,
                              isSecret: false,
                              isVisible: true,
                              onToggle: null,
                              isCopied: _pubKeyCopied,
                              onCopy: () => _copyPub(npub),
                            ),

                            SizedBox(height: midGap + 8),

                            KeyCard(
                              label: l10n.keysPrivateKeyTitle,
                              helper: l10n.keysPrivateKeySubtitle,
                              keyValue: nsec,
                              isSecret: true,
                              isVisible: _nsecVisible,
                              onToggle: () => setState(
                                  () => _nsecVisible = !_nsecVisible),
                              isCopied: _privKeyCopied,
                              onCopy: () => _copyPriv(nsec),
                            ),

                            SizedBox(height: midGap),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Terms + Save & Continue — pinned to the bottom ──────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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

                        SizedBox(height: midGap),

                        GestureDetector(
                          onTap: canContinue
                              ? () => _saveAndContinue(context, args, nsec)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: canContinue
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: canContinue
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.22),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                l10n.keysSaveAndContinue,
                                style: TextStyle(
                                  color: canContinue
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.outline,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ],
      ),
    );
  }
}

/// Soft, decorative blue glow used as an ambient background accent.
class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 340,
        height: 340,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
