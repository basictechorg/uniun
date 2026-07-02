import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_conversation_tile.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Side drawer for Shiv. Lists the user's chat history (conversations).
///
/// Add as `drawer:` on the Shiv page Scaffold. Open programmatically via
/// [ShivHistoryDrawer.open].
class ShivHistoryDrawer extends StatelessWidget {
  const ShivHistoryDrawer({super.key});

  static void open(BuildContext context) => Scaffold.of(context).openDrawer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final top = MediaQuery.of(context).padding.top;

    return Drawer(
      width: 280,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 8,
              top: top + 16,
              bottom: 12,
            ),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Text(
                  l10n.shivConversations,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context
                        .read<ShivAIBloc>()
                        .add(const ShivAIEvent.createConversation());
                  },
                  icon: const Icon(Icons.add_rounded),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: l10n.shivNewConversationTooltip,
                ),
              ],
            ),
          ),
          const Expanded(
            child: _ConversationsSection(),
          ),
        ],
      ),
    );
  }
}

// ── Conversations section ───────────────────────────────────────────────────

class _ConversationsSection extends StatelessWidget {
  const _ConversationsSection();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShivAIBloc, ShivAIState>(
      builder: (context, state) {
        if (state.conversations.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                l10n.shivNoConversations,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final conv in state.conversations)
              ShivConversationTile(
                conversation: conv,
                isActive: state.activeConversation?.conversationId ==
                    conv.conversationId,
                onTap: () {
                  Navigator.of(context).pop();
                  context
                      .read<ShivAIBloc>()
                      .add(ShivAIEvent.openConversation(conv.conversationId));
                },
                onDelete: () {
                  context
                      .read<ShivAIBloc>()
                      .add(ShivAIEvent.deleteConversation(conv.conversationId));
                },
              ),
          ],
        );
      },
    );
  }
}
