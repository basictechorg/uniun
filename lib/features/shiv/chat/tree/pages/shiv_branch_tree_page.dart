import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/chat/tree/widgets/branch_tree_graph.dart';
import 'package:uniun/features/shiv/chat/tree/widgets/node_action_panel.dart';

class ShivBranchTreePage extends StatelessWidget {
  const ShivBranchTreePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<ShivAIBloc, ShivAIState>(
      // Pop exactly once: when activeLeafMessageId changes (different branch tapped)
      listenWhen: (prev, curr) =>
          prev.activeConversation?.activeLeafMessageId !=
          curr.activeConversation?.activeLeafMessageId,
      listener: (context, state) => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        body: BlocBuilder<ShivAIBloc, ShivAIState>(
          builder: (context, state) {
            // allMessages is populated on _onOpenConversation.
            // Fallback to state.messages (current branch) if it wasn't set.
            final allMsgs = state.allMessages.isNotEmpty
                ? state.allMessages
                : state.messages;
            final activeLeaf = state.activeConversation?.activeLeafMessageId;
            final selectedId = state.selectedNodeMessageId;
            final selectedMsg = selectedId != null
                ? allMsgs.where((m) => m.messageId == selectedId).firstOrNull
                : null;

            return Stack(
              children: [
                // ── Background dot pattern ─────────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                      painter: _DotPatternPainter(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.4))),
                ),

                // ── Main content ───────────────────────────────────────
                Column(
                  children: [
                    _TreeHeader(title: l10n.shivConversationTree),

                    Expanded(
                      child: allMsgs.isEmpty
                          ? _EmptyTree(l10n: l10n)
                          : GestureDetector(
                              // Tap on canvas outside a node → dismiss panel
                              onTap: selectedId != null
                                  ? () => context.read<ShivAIBloc>().add(
                                        const ShivAIEvent.selectGraphNode(null),
                                      )
                                  : null,
                              behavior: HitTestBehavior.translucent,
                              child: BranchTreeGraph(
                                allMessages: allMsgs,
                                activeLeafMessageId: activeLeaf,
                                selectedNodeMessageId: selectedId,
                                onNodeTap: (msgId) {
                                  // Same node tapped → toggle off
                                  if (msgId == selectedId) {
                                    context.read<ShivAIBloc>().add(
                                          const ShivAIEvent.selectGraphNode(
                                              null),
                                        );
                                  } else {
                                    context.read<ShivAIBloc>().add(
                                          ShivAIEvent.selectGraphNode(msgId),
                                        );
                                  }
                                },
                              ),
                            ),
                    ),
                  ],
                ),

                // ── Scrim: tap outside panel dismisses it ──────────────
                if (selectedMsg != null)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => context.read<ShivAIBloc>().add(
                            const ShivAIEvent.selectGraphNode(null),
                          ),
                      behavior: HitTestBehavior.opaque,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),

                // ── Node action panel ──────────────────────────────────
                if (selectedMsg != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () {}, // absorb — prevent scrim dismissal
                      child: NodeActionPanel(
                        message: selectedMsg,
                        messageCount: allMsgs
                            .where((m) =>
                                m.conversationId == selectedMsg.conversationId)
                            .length,
                        isActiveBranch: activeLeaf == selectedMsg.messageId,
                        onDismiss: () => context.read<ShivAIBloc>().add(
                              const ShivAIEvent.selectGraphNode(null),
                            ),
                        onOpenBranch: () {
                          final alreadyActive =
                              activeLeaf == selectedMsg.messageId;
                          context.read<ShivAIBloc>().add(
                                ShivAIEvent.switchBranch(selectedMsg.messageId),
                              );
                          // If leaf won't change, BlocListener won't fire —
                          // pop manually so user always returns to chat.
                          if (alreadyActive) Navigator.pop(context);
                        },
                      ),
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

// ── Header ──────────────────────────────────────────────────────────────────

class _TreeHeader extends StatelessWidget {
  const _TreeHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          UniunBackButton(
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          SvgPicture.asset(
            'assets/images/network_node.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyTree extends StatelessWidget {
  const _EmptyTree({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/images/network_node.svg',
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.shivEmptyTreeTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.shivEmptyTreeBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot pattern background ───────────────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  const _DotPatternPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => old.color != color;
}
