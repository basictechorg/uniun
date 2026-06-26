import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/onboarding/widgets/field_label.dart';
import 'package:uniun/features/onboarding/widgets/onboarding_app_bar.dart';
import 'package:uniun/features/settings/cubit/edit_profile_cubit.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EditProfileCubit>(),
      child: const _EditProfileContent(),
    );
  }
}

class _EditProfileContent extends StatefulWidget {
  const _EditProfileContent();

  @override
  State<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<_EditProfileContent> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _about;
  late final TextEditingController _avatarUrl;
  late final TextEditingController _nip05;
  bool _controllersInit = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _about.dispose();
    _avatarUrl.dispose();
    _nip05.dispose();
    super.dispose();
  }

  void _initControllers(EditProfileState state) {
    if (_controllersInit) return;
    _name = TextEditingController(text: state.name);
    _username = TextEditingController(text: state.username);
    _about = TextEditingController(text: state.about);
    _avatarUrl = TextEditingController(text: state.avatarUrl);
    _nip05 = TextEditingController(text: state.nip05);
    _controllersInit = true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditProfileCubit, EditProfileState>(
      listener: (context, state) {
        if (state.status == EditProfileStatus.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.editProfileSaved)),
          );
          Navigator.pop(context);
        }
        if (state.status == EditProfileStatus.error &&
            state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      builder: (context, state) {
        if (state.status == EditProfileStatus.loading) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(
              child: DropLoadingIndicator(color: AppColors.primary),
            ),
          );
        }

        _initControllers(state);
        final cubit = context.read<EditProfileCubit>();
        final isSaving = state.status == EditProfileStatus.saving;
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
                                      l10n.editProfileEyebrow.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.editProfileTitle,
                                      // Display serif (Newsreader) — reserved for
                                      // headline moments. h1 28 · semibold.
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
                                      l10n.editProfileSubtitle,
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

                              // ── Avatar preview ─────────────────────────────
                              UserAvatar(
                                seed: state.username.isNotEmpty
                                    ? state.username
                                    : state.name,
                                photoUrl: state.avatarUrl.isNotEmpty
                                    ? state.avatarUrl
                                    : null,
                                size: 96,
                                showBorder: true,
                              ),

                              const SizedBox(height: 28),

                              // ── Display name ───────────────────────────────
                              FieldLabel(l10n.editProfileDisplayName),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                onChanged: cubit.updateName,
                                decoration: InputDecoration(
                                  hintText: l10n.editProfileDisplayNameHint,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Username ───────────────────────────────────
                              FieldLabel(l10n.editProfileUsername),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _username,
                                onChanged: cubit.updateUsername,
                                decoration: InputDecoration(
                                  hintText: l10n.editProfileUsernameHint,
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
                                  prefixIconConstraints: const BoxConstraints(
                                      minWidth: 0, minHeight: 0),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── About ──────────────────────────────────────
                              FieldLabel(l10n.editProfileAbout),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _about,
                                maxLines: 4,
                                onChanged: cubit.updateAbout,
                                decoration: InputDecoration(
                                  hintText: l10n.editProfileAboutHint,
                                  alignLabelWithHint: true,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Avatar URL ─────────────────────────────────
                              FieldLabel(l10n.editProfileAvatarUrl),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _avatarUrl,
                                onChanged: cubit.updateAvatarUrl,
                                decoration: InputDecoration(
                                  hintText: l10n.editProfileAvatarUrlHint,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── NIP-05 ─────────────────────────────────────
                              FieldLabel(l10n.editProfileNip05),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _nip05,
                                onChanged: cubit.updateNip05,
                                decoration: InputDecoration(
                                  hintText: l10n.editProfileNip05Hint,
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ── Save button ────────────────────────────────
                              AnimatedOpacity(
                                opacity: isSaving ? 0.6 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                child: GestureDetector(
                                  onTap: isSaving ? null : () => cubit.save(),
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
                                      boxShadow: isSaving
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.28),
                                                blurRadius: 24,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: isSaving
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: DropLoadingIndicator(
                                                size: 18,
                                                color: AppColors.onPrimary,
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  l10n.editProfileSaveButton,
                                                  style: const TextStyle(
                                                    color: AppColors.onPrimary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.check_rounded,
                                                  color: AppColors.onPrimary,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Privacy reassurance pill ───────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_user_rounded,
                                        size: 13, color: AppColors.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      l10n.editProfileEncrypted,
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
      },
    );
  }
}

/// Two soft brand-blue radial glows bleeding in from opposite corners — the
/// ambient backdrop mirrored from the onboarding flow. Purely decorative.
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
