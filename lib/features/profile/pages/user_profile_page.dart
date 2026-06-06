import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/profile/bloc/user_profile_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

class UserProfileArgs {
  const UserProfileArgs({required this.pubkeyHex, this.hintName});
  final String pubkeyHex;
  final String? hintName;
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final String hex;
    final String? hintName;
    if (args is UserProfileArgs && args.pubkeyHex.isNotEmpty) {
      hex = args.pubkeyHex;
      hintName = args.hintName;
    } else if (args is String && args.isNotEmpty) {
      hex = args;
      hintName = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold();
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<UserProfileBloc>()
            ..add(LoadUserProfileEvent(hex, hintName: hintName)),
        ),
      ],
      child: const _UserProfileView(),
    );
  }
}

class _UserProfileView extends StatelessWidget {
  const _UserProfileView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: BlocBuilder<UserProfileBloc, UserProfileState>(
          builder: (context, state) {
            if (state.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(state: state, l10n: l10n)),
                if (state.notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          l10n.userProfileNoNotes,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final note = state.notes[i];
                        return NoteCard(
                          key: ValueKey(note.id),
                          note: note,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.thread,
                            arguments: note.id,
                          ),
                        );
                      },
                      childCount: state.notes.length,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.l10n});

  final UserProfileState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final hex = state.pubkeyHex ?? '';
    final profile = state.profile;
    final hint = state.hintName?.trim();
    final name = profile?.name?.trim().isNotEmpty == true
        ? profile!.name!
        : (profile?.username?.trim().isNotEmpty == true
            ? profile!.username!
            : (hint != null && hint.isNotEmpty
                ? hint
                : (hex.length > 12 ? '${hex.substring(0, 12)}…' : hex)));
    final handle = profile?.username?.trim().isNotEmpty == true
        ? '@${profile!.username!}'
        : (hex.length > 16 ? '${hex.substring(0, 16)}…' : hex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  UserAvatar(
                    seed: hex,
                    photoUrl: profile?.avatarUrl,
                    size: 84,
                    showBorder: true,
                  ),
                  const Spacer(),
                  _FollowButton(state: state),
                  const SizedBox(width: 8),
                  _DmButton(pubkeyHex: hex),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                handle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (profile?.about?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  profile!.about!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
              if (profile?.nip05?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile!.nip05!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.outlineVariant),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.state});

  final UserProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFollowing = state.isFollowing;
    final onPressed = state.busy
        ? null
        : () => context.read<UserProfileBloc>().add(const ToggleFollowEvent());

    if (isFollowing) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(l10n.userProfileFollowing),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(l10n.userProfileFollow),
    );
  }
}

class _DmButton extends StatelessWidget {
  const _DmButton({required this.pubkeyHex});

  final String pubkeyHex;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.pushNamed(
        context,
        AppRoutes.createDm,
        arguments: pubkeyHex,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Icon(Icons.mail_outline_rounded, size: 18),
    );
  }
}
