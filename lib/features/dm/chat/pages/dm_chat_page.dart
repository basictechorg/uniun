import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_button.dart';
import 'package:uniun/common/qr/uniun_qr_card.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/common/widgets/note_card/dm_note_card.dart';
import 'package:uniun/common/widgets/note_card/dm_own_note_card.dart';
import 'package:uniun/common/widgets/note_card/referenced_messages.dart';
import 'package:uniun/common/widgets/user_avatar.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/repositories/dm_conversation_repository.dart';
import 'package:uniun/features/dm/chat/bloc/dm_chat_bloc.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

class DmChatPage extends StatelessWidget {
  const DmChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final otherPubkey = ModalRoute.of(context)!.settings.arguments as String;

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
  List<String> _conversationRelays = const [];

  @override
  void initState() {
    super.initState();
    _resolveActiveUser();
  }

  Future<void> _resolveActiveUser() async {
    final res = await getIt<GetActiveUserProfileUseCase>().call();
    if (mounted) {
      res.fold((_) {}, (profile) {
        setState(() {
          _myPubkeyHex = profile.pubkeyHex;
          _myNpub = Nip19.encodePubkey(profile.pubkeyHex);
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

  void _showQr(String otherPubkeyHex) {
    if (_myNpub == null) return;
    final partnerNpub = Nip19.encodePubkey(otherPubkeyHex);
    showDialog<void>(
      context: context,
      builder: (_) => UniunQrCard.dmConversation(
        partnerNpub: partnerNpub,
        myNpub: _myNpub!,
        conversationRelays: _conversationRelays,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openThread(BuildContext context, String messageId) {
    Navigator.pushNamed(context, AppRoutes.thread, arguments: messageId);
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
        final messagesById = <String, NoteEntity>{
          for (final m in state.messages) m.id: m,
        };

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
                  onTap: () => _showQr(state.otherPubkey!),
                  tooltip: 'Share keys',
                ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  context.read<DmChatBloc>().add(DmChatRefreshEvent());
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: state.isLoading && state.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
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
                          final refIds = msg.eTagRefs
                              .where((id) => id != msg.replyToEventId)
                              .toList();
                          final card = isMe
                              ? DmOwnNoteCard(
                                  key: ValueKey(msg.eventId),
                                  note: msg,
                                  profile: state.profiles[msg.authorPubkey],
                                  onTap: () => _openThread(context, msg.id),
                                )
                              : DmNoteCard(
                                  key: ValueKey(msg.eventId),
                                  note: msg,
                                  profile: state.profiles[msg.authorPubkey],
                                  onTap: () => _openThread(context, msg.id),
                                );
                          if (refIds.isEmpty) return card;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ReferencedMessages(
                                refs: refIds
                                    .map((id) => messagesById[id])
                                    .toList(),
                                unavailableLabel:
                                    l10n.vishnuReferenceUnavailable,
                                onTapRef: (note) =>
                                    _openThread(context, note.id),
                              ),
                              card,
                            ],
                          );
                        },
                      ),
              ),
              ComposerHost(
                hintText: l10n.chatMessageHint,
                isSending: state.isSending,
                referenceCandidates: state.messages.cast<NoteEntity>(),
                onSend: (text, refs) => context.read<DmChatBloc>().add(
                      DmChatSendEvent(content: text, mentionRefs: refs),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
