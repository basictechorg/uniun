import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_button.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/jump_to_bottom_button.dart';
import 'package:uniun/common/widgets/note_card/dm_note_card.dart';
import 'package:uniun/common/widgets/note_card/dm_own_note_card.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/repositories/dm_conversation_repository.dart';
import 'package:uniun/features/dm/chat/bloc/dm_chat_bloc.dart';
import 'package:uniun/features/shiv/generation/chat_helpers.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

class DmChatPage extends StatelessWidget {
  const DmChatPage({super.key, required this.otherPubkey});

  /// Recipient's hex pubkey (already normalised by the chatDm route).
  final String otherPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<DmChatBloc>()..add(DmChatLoadEvent(otherPubkey: otherPubkey)),
      child: const _DmChatView(),
    );
  }
}

class _DmChatView extends StatefulWidget {
  const _DmChatView();

  @override
  State<_DmChatView> createState() => _DmChatViewState();
}

class _DmChatViewState extends State<_DmChatView> {
  final _scrollController = ScrollController();

  // To identify if a message is ours.
  String? _myPubkeyHex;
  String? _myNpub;
  String? _myAvatarUrl;
  List<String> _conversationRelays = const [];

  final Set<String> _everVisible = <String>{};

  /// Whether the jump-to-latest button is showing (set when scrolled above the
  /// bottom — on this reversed list, that means away from the minimum offset).
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _resolveActiveUser();
    _scrollController.addListener(_onScroll);
  }

  /// On a reversed list the newest message sits at the minimum scroll offset, so
  /// reaching it (the default position on open) marks the conversation read.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels <= pos.minScrollExtent + 8) {
      context.read<DmChatBloc>().add(DmChatMarkAllSeenEvent());
    }

    final showJump =
        pos.pixels - pos.minScrollExtent > kJumpToBottomTolerance;
    if (showJump != _showJumpButton) {
      setState(() => _showJumpButton = showJump);
    }
  }

  /// Jumps to the newest message (offset 0 on this reversed list) and marks the
  /// conversation read.
  void _jumpToLatest() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    context.read<DmChatBloc>().add(DmChatMarkAllSeenEvent());
  }

  void _onMessageVisibility(String eventId, VisibilityInfo info) {
    if (info.visibleFraction >= 0.5) {
      _everVisible.add(eventId);
    } else if (info.visibleFraction == 0 && _everVisible.contains(eventId)) {
      // visibility_detector fires its callbacks via a scheduler task that can
      // run after the widget tree has been disposed (route pop). Touching
      // `context` then throws — guard with `mounted`.
      if (!mounted) return;
      context.read<DmChatBloc>().add(DmChatMarkSeenEvent(eventId));
    }
  }

  Future<void> _resolveActiveUser() async {
    final res = await getIt<GetActiveUserProfileUseCase>().call();
    if (mounted) {
      res.fold((_) {}, (profile) {
        setState(() {
          _myPubkeyHex = profile.pubkeyHex;
          _myNpub = Nip19.encodePubkey(profile.pubkeyHex);
          _myAvatarUrl = profile.avatarUrl;
        });
      });
    }
  }

  Future<void> _loadConversationRelays(String otherPubkeyHex) async {
    final result = await getIt<DmConversationRepository>()
        .getConversationByOtherPubkey(otherPubkeyHex);
    if (!mounted) return;
    setState(() {
      _conversationRelays = result.fold((_) => const [], (c) => c.relays);
    });
  }

  void _showQr(DmChatState state) {
    final otherPubkeyHex = state.otherPubkey;
    if (otherPubkeyHex == null || _myNpub == null) return;
    final partnerNpub = Nip19.encodePubkey(otherPubkeyHex);
    final partner = state.profiles[otherPubkeyHex];
    final me = _myPubkeyHex != null ? state.profiles[_myPubkeyHex!] : null;
    UniunQrCard.show(
      context,
      card: UniunQrCard.dmConversation(
        partnerNpub: partnerNpub,
        partnerName: partner?.name,
        partnerSeed: otherPubkeyHex,
        partnerAvatarUrl: partner?.avatarUrl,
        myNpub: _myNpub!,
        myName: me?.name,
        mySeed: _myPubkeyHex,
        myAvatarUrl: _myAvatarUrl,
        conversationRelays: _conversationRelays,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _openThread(BuildContext context, String messageId) {
    context.pushNamed(AppRoutes.thread, pathParameters: {'noteId': messageId});
  }

  /// Display name for the reply strip — the replied-to message's author
  /// (either participant), falling back to a shortened pubkey.
  String? _replyName(DmChatState state) {
    final note = state.replyingToNote;
    if (note == null) return null;
    final name = state.profiles[note.authorPubkey]?.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final pk = note.authorPubkey;
    return pk.length > 12 ? '${pk.substring(0, 12)}...' : pk;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DmChatBloc, DmChatState>(
      listenWhen: (prev, curr) =>
          prev.otherPubkey != curr.otherPubkey ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state.otherPubkey != null && _conversationRelays.isEmpty) {
          _loadConversationRelays(state.otherPubkey!);
        }
      },
      builder: (context, state) {
        final shortKey =
            state.otherPubkey != null && state.otherPubkey!.length > 12
            ? '${state.otherPubkey!.substring(0, 12)}...'
            : state.otherPubkey ?? 'Chat';

        final l10n = AppLocalizations.of(context)!;

        final otherPubkey = state.otherPubkey;
        final otherProfile = otherPubkey == null
            ? null
            : state.profiles[otherPubkey];
        final displayName = otherProfile?.name?.trim().isNotEmpty == true
            ? otherProfile!.name!.trim()
            : shortKey;

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: UniunBackButton(
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                UserAvatar(
                  seed: otherPubkey ?? 'dm',
                  photoUrl: otherProfile?.avatarUrl,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayName,
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
              if (state.otherPubkey != null && _myNpub != null)
                UniunQrButton(
                  onTap: () => _showQr(state),
                  tooltip: 'Share keys',
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    state.isLoading && state.messages.isEmpty
                        ? const Center(child: DropLoadingIndicator())
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true, // show latest at bottom
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            itemCount: state.messages.length,
                            itemBuilder: (context, index) {
                              final msg = state.messages[index];
                              final isMe = _myPubkeyHex != null &&
                                  msg.authorPubkey == _myPubkeyHex;
                              // The DM cards self-load their profile via NoteCardCubit.
                              final card = isMe
                                  ? DmOwnNoteCard(
                                      key: ValueKey(msg.id),
                                      note: msg,
                                      onTap: () => _openThread(context, msg.id),
                                      onReply: () => context
                                          .read<DmChatBloc>()
                                          .add(DmChatStartReplyEvent(msg)),
                                    )
                                  : DmNoteCard(
                                      key: ValueKey(msg.id),
                                      note: msg,
                                      onTap: () => _openThread(context, msg.id),
                                      onReply: () => context
                                          .read<DmChatBloc>()
                                          .add(DmChatStartReplyEvent(msg)),
                                    );
                              return VisibilityDetector(
                                key: ValueKey('dm-${msg.id}'),
                                onVisibilityChanged: (info) =>
                                    _onMessageVisibility(msg.id, info),
                                child: card,
                              );
                            },
                          ),
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: JumpToBottomButton(
                        visible: _showJumpButton,
                        onPressed: _jumpToLatest,
                        tooltip: AppLocalizations.of(context)!.jumpToLatest,
                      ),
                    ),
                  ],
                ),
              ),
              ComposerHost(
                hintText: l10n.chatMessageHint,
                isSending: state.isSending,
                entityContext: entityContextLines(state.messages),
                replyingToName: _replyName(state),
                replyingToPreview: state.replyingToNote?.content,
                onClearReply: () =>
                    context.read<DmChatBloc>().add(DmChatCancelReplyEvent()),
                onSend: (text, refs, attachments) =>
                    context.read<DmChatBloc>().add(
                          DmChatSendEvent(
                            content: text,
                            mentionRefs: refs,
                            attachments: attachments,
                          ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
