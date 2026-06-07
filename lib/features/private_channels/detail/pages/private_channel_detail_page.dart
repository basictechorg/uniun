import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_button.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/common/widgets/note_card/note_card.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/features/private_channels/detail/bloc/private_channel_detail_bloc.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';

class PrivateChannelDetailPage extends StatelessWidget {
  final String groupId;
  const PrivateChannelDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<PrivateChannelDetailBloc>(param1: groupId),
        ),
      ],
      child: const _PrivateChannelDetailView(),
    );
  }
}

class _PrivateChannelDetailView extends StatefulWidget {
  const _PrivateChannelDetailView();

  @override
  State<_PrivateChannelDetailView> createState() => _PrivateChannelDetailViewState();
}

class _PrivateChannelDetailViewState extends State<_PrivateChannelDetailView> {
  final _scrollController = ScrollController();
  final Set<String> _everVisible = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Reaching the bottom (newest message) marks the whole channel read.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 8) {
      context
          .read<PrivateChannelDetailBloc>()
          .add(MarkAllPrivateChannelSeenEvent());
    }
  }

  void _onMessageVisibility(String eventId, VisibilityInfo info) {
    if (info.visibleFraction >= 0.5) {
      _everVisible.add(eventId);
    } else if (info.visibleFraction == 0 && _everVisible.contains(eventId)) {
      context
          .read<PrivateChannelDetailBloc>()
          .add(MarkPrivateChannelMessageSeenEvent(eventId));
    }
  }

  void _openThread(BuildContext context, String messageId) {
    context.pushNamed(AppRoutes.thread, pathParameters: {'noteId': messageId});
  }

  void _showJoinRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return BlocProvider.value(
          value: context.read<PrivateChannelDetailBloc>(),
          child: BlocBuilder<PrivateChannelDetailBloc,
              PrivateChannelDetailState>(
            builder: (ctx, state) {
              return _JoinRequestsSheet(
                requests: state.joinRequests,
                profiles: state.profiles,
                isApproving: state.isApproving,
                onApprove: (keyPackage) {
                  ctx.read<PrivateChannelDetailBloc>().add(
                        ApproveJoinRequestEvent(keyPackage),
                      );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PrivateChannelDetailBloc, PrivateChannelDetailState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state.isLeft) {
          context.goNamed(AppRoutes.home);
        }
      },
      builder: (context, state) {
        final title = state.channel?.name ?? "Private Channel";
        final requestsCount = state.joinRequests.length;

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
            titleSpacing: 0,
            title: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 16, color: AppColors.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (state.isAdmin)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.group_add_rounded),
                      onPressed: () => _showJoinRequests(context),
                    ),
                    if (requestsCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$requestsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (state.channel != null) ...[
                UniunQrButton(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => UniunQrCard.privateChannel(
                      name: state.channel!.name,
                      groupId: state.groupId,
                      relays: state.channel!.relays,
                    ),
                  ),
                  tooltip: 'Share QR',
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'leave') {
                    context.read<PrivateChannelDetailBloc>().add(LeavePrivateChannelEvent());
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('Leave Channel', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
          body: state.isPendingApproval
              ? const _PendingApprovalView()
              : Column(
                  children: [
                    Expanded(
                      child: state.isLoading && state.messages.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: false, // oldest at top, newest at bottom
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) {
                                final msg = state.messages[index];
                                // NoteCard self-loads its author profile.
                                return VisibilityDetector(
                                  key: ValueKey('pc-${msg.id}'),
                                  onVisibilityChanged: (info) =>
                                      _onMessageVisibility(msg.id, info),
                                  child: NoteCard(
                                    key: ValueKey(msg.id),
                                    note: msg,
                                    onTap: () => _openThread(context, msg.id),
                                  ),
                                );
                              },
                            ),
                    ),
                    ComposerHost(
                      hintText: AppLocalizations.of(context)!.chatMessageHint,
                      onSend: (text, refs) =>
                          context.read<PrivateChannelDetailBloc>().add(
                                SendPrivateChannelMessageEvent(text,
                                    mentionRefs: refs),
                              ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PendingApprovalView extends StatelessWidget {
  const _PendingApprovalView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 56,
              color: AppColors.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              "Pending approval",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your request to join has been sent. You'll be able to read and send messages once the channel admin approves you.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinRequestsSheet extends StatelessWidget {
  const _JoinRequestsSheet({
    required this.requests,
    required this.profiles,
    required this.isApproving,
    required this.onApprove,
  });

  final List requests;
  final Map<String, ProfileEntity> profiles;
  final bool isApproving;
  final void Function(String keyPackageB64) onApprove;

  String _shortNpub(String pubkeyHex) {
    try {
      final npub = Nip19.encodePubkey(pubkeyHex);
      if (npub.length <= 18) return npub;
      return '${npub.substring(0, 10)}…${npub.substring(npub.length - 6)}';
    } catch (_) {
      return '${pubkeyHex.substring(0, 8)}…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.group_add_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.pendingRequestsTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (requests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${requests.length}',
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.pendingRequestsSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 36,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Text(
                      l10n.pendingRequestsEmpty,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final req = requests[i];
                    final pubkey = req.senderPubkey as String;
                    final profile = profiles[pubkey];
                    final name = (profile?.name?.trim().isNotEmpty == true)
                        ? profile!.name!
                        : l10n.pendingRequestsNewMember;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            seed: pubkey,
                            photoUrl: profile?.avatarUrl,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shortNpub(pubkey),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isApproving
                                ? null
                                : () {
                                    onApprove(req.keyPackageB64 as String);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isApproving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : Text(
                                    l10n.pendingRequestsApprove,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

