import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/follow/action/bloc/follow_action_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

class FollowOrDmActionArgs {
  const FollowOrDmActionArgs({required this.payload, this.autoFollow = false});

  final UniunQrPayload payload;
  final bool autoFollow;
}

class FollowOrDmActionPage extends StatelessWidget {
  const FollowOrDmActionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    final FollowOrDmActionArgs resolved;
    if (args is FollowOrDmActionArgs &&
        args.payload.kind == UniunQrKind.user) {
      resolved = args;
    } else if (args is UniunQrPayload && args.kind == UniunQrKind.user) {
      resolved = FollowOrDmActionArgs(payload: args);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold();
    }

    return BlocProvider(
      create: (_) => getIt<FollowActionBloc>()
        ..add(ResolveIdentityEvent(
          rawId: resolved.payload.id,
          displayName: resolved.payload.name,
        )),
      child: _FollowOrDmActionView(args: resolved),
    );
  }
}

class _FollowOrDmActionView extends StatefulWidget {
  const _FollowOrDmActionView({required this.args});

  final FollowOrDmActionArgs args;

  @override
  State<_FollowOrDmActionView> createState() => _FollowOrDmActionViewState();
}

class _FollowOrDmActionViewState extends State<_FollowOrDmActionView> {
  bool _autoFollowFired = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final payload = widget.args.payload;

    return BlocConsumer<FollowActionBloc, FollowActionState>(
      listenWhen: (prev, curr) =>
          prev.pubkeyHex != curr.pubkeyHex ||
          prev.success != curr.success ||
          prev.errorMessage != curr.errorMessage ||
          prev.invalid != curr.invalid,
      listener: (context, state) {
        if (widget.args.autoFollow &&
            !_autoFollowFired &&
            state.pubkeyHex != null) {
          _autoFollowFired = true;
          context.read<FollowActionBloc>().add(const SubmitFollowEvent());
        }
        if (state.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.followActionSuccess)),
          );
          Navigator.of(context).pop();
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state.invalid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.followActionInvalidKey)),
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        if (widget.args.autoFollow) {
          return const Scaffold(
            backgroundColor: AppColors.surface,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final hex = state.pubkeyHex;
        final displayName = _resolveDisplayName(state, payload, l10n);

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              l10n.followActionTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Center(
                    child: UserAvatar(
                      seed: hex ?? payload.id,
                      photoUrl: state.profile?.avatarUrl,
                      size: 96,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (state.profile?.nip05 != null) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        state.profile!.nip05!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton(
                    onPressed: hex == null || state.busy
                        ? null
                        : () => context
                            .read<FollowActionBloc>()
                            .add(const SubmitFollowEvent()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: state.busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(l10n.followActionFollowCta),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: hex == null || state.busy
                        ? null
                        : () => Navigator.of(context).pushReplacementNamed(
                              AppRoutes.createDm,
                              arguments: payload,
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(l10n.followActionDmCta),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveDisplayName(
    FollowActionState state,
    UniunQrPayload payload,
    AppLocalizations l10n,
  ) {
    final profileName = state.profile?.name?.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final qrName = payload.name?.trim();
    if (qrName != null && qrName.isNotEmpty) return qrName;
    final hex = state.pubkeyHex;
    if (hex != null && hex.length > 12) return '${hex.substring(0, 12)}…';
    return l10n.followActionTitle;
  }
}
