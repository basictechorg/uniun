import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/composer/composer_host.dart';
import 'package:uniun/common/widgets/note_card/dm_note_card.dart';
import 'package:uniun/common/widgets/note_card/dm_own_note_card.dart';
import 'package:uniun/common/widgets/note_card/referenced_messages.dart';
import 'package:uniun/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _resolveActiveUser();
  }

  Future<void> _resolveActiveUser() async {
    final res = await getIt<GetActiveUserProfileUseCase>().call();
    if (mounted) {
      res.fold((_) {}, (profile) {
        setState(() => _myPubkeyHex = profile.pubkeyHex);
      });
    }
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
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
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

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.1),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  radius: 16,
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  shortKey,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            actions: [
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
