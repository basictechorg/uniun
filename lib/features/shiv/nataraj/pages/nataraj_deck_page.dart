import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/app_settings_usecases.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/chat/pages/shiv_chat_page.dart';
import 'package:uniun/features/shiv/nataraj/bloc/nataraj_bloc.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_card_widget.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_coach_overlay.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_edge_labels.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_drawer.dart';
import 'package:uniun/features/shiv/nataraj/widgets/nataraj_empty_state.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// The Nataraj swipe-deck screen — Shiv tab's home in Task 15.
///
/// Provides its own [NatarajBloc] and dispatches [NatarajEvent.loadDeck] on
/// mount. Model gate: if no LLM is installed, redirects to AI model selection.
///
/// Header: scope pill (left) + new-chat + history (right).
/// Body: switches on [NatarajStatus]:
///   - loading   → spinner + [l10n.natarajGenerating]
///   - ready     → swipe deck (card + edge labels + buttons + coach overlay)
///   - needsMoreNotes / exhausted → [NatarajEmptyState]
///   - error     → retry button
///
/// Seed-chat: BlocListener on [state.seedChatParagraph] fires
/// [ShivAIEvent.createConversationSeeded] on the ambient [ShivAIBloc] (or
/// falls back to getIt when no ambient bloc is available).
class NatarajDeckPage extends StatelessWidget {
  const NatarajDeckPage({
    super.key,
    this.manasIds = const [],
    this.onDrawerChanged,
  });

  /// Optional initial scope filter (list of manas IDs).
  final List<String> manasIds;

  /// Called when the [NatarajDrawer] opens or closes. Wire this to
  /// [ShivPage]'s [_onDrawerChanged] so [FloatingNav] hides while the drawer
  /// is open — same pattern as [ShivChatPage.onDrawerChanged].
  final ValueChanged<bool>? onDrawerChanged;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NatarajBloc>()
        ..add(NatarajEvent.loadDeck(manasIds)),
      child: _NatarajDeckView(
        initialManasIds: manasIds,
        onDrawerChanged: onDrawerChanged,
      ),
    );
  }
}

// ── Inner stateful widget (model gate + coach dismiss) ────────────────────────

class _NatarajDeckView extends StatefulWidget {
  const _NatarajDeckView({
    required this.initialManasIds,
    this.onDrawerChanged,
  });
  final List<String> initialManasIds;
  final ValueChanged<bool>? onDrawerChanged;

  @override
  State<_NatarajDeckView> createState() => _NatarajDeckViewState();
}

class _NatarajDeckViewState extends State<_NatarajDeckView> {
  /// Local flag to suppress the coach overlay independently of bloc state
  /// (so dismissing it survives without a dedicated bloc event).
  bool _coachDismissed = false;

  /// Lets the fallback action buttons trigger the card's fly-off animation
  /// instead of advancing the deck instantly. Lives here (not in the rebuilt
  /// [_DeckBody]) so it survives bloc emissions and stays bound to the card.
  final NatarajCardController _cardController = NatarajCardController();

  @override
  void initState() {
    super.initState();
    _loadCoachSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkModel());
  }

  /// Seed the coach gate from the persisted once-ever flag (via the settings
  /// repository) so it never reappears after dismissal, across app restarts.
  Future<void> _loadCoachSeen() async {
    final seen = (await getIt<GetNatarajCoachSeenUseCase>().call())
        .fold((_) => false, (v) => v);
    if (mounted && seen) setState(() => _coachDismissed = true);
  }

  Future<void> _checkModel() async {
    if (!mounted) return;
    final hasModel = await getIt<HasActiveLlmModelUseCase>().call();
    if (!mounted) return;
    if (!hasModel) {
      context.pushReplacementNamed(AppRoutes.aiModelSelection);
    }
  }

  /// Fires [ShivAIEvent.createConversationSeeded] on the ambient [ShivAIBloc]
  /// when available, or obtains one from getIt and pushes the chat page with
  /// a fresh BlocProvider in the standalone (non-Shiv-tab) case.
  void _openSeededChat(BuildContext context, String paragraph) {
    ShivAIBloc? ambientBloc;
    try {
      ambientBloc = context.read<ShivAIBloc>();
    } catch (_) {
      ambientBloc = null;
    }

    if (ambientBloc != null) {
      // In-Shiv case (Task 15): the ambient bloc drives the tab UI, so
      // just fire the event — ShivPage's BlocBuilder switches to ShivChatPage.
      ambientBloc.add(
        ShivAIEvent.createConversationSeeded(paragraph),
      );
    } else {
      // Standalone / Brahma-deep-link case: no ambient ShivAIBloc.
      // Spin up a fresh one from getIt and push the chat page with it.
      final freshBloc = getIt<ShivAIBloc>()
        ..add(ShivAIEvent.createConversationSeeded(paragraph));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<ShivAIBloc>.value(
            value: freshBloc,
            child: ShivChatPage(onDrawerChanged: (_) {}),
          ),
        ),
      );
    }
  }

  /// Opens a new (unseeded) chat the same way [_ShivLanding] does in
  /// shiv_page.dart: checks the model via [HasActiveLlmModelUseCase], then
  /// fires [ShivAIEvent.createConversation] on the ambient bloc, or pushes a
  /// standalone chat in the non-Shiv context.
  Future<void> _onNewChat(BuildContext context) async {
    final hasModel = await getIt<HasActiveLlmModelUseCase>().call();
    if (!context.mounted) return;
    if (!hasModel) {
      context.pushNamed(AppRoutes.aiModelSelection);
      return;
    }

    ShivAIBloc? ambientBloc;
    try {
      ambientBloc = context.read<ShivAIBloc>();
    } catch (_) {
      ambientBloc = null;
    }

    if (ambientBloc != null) {
      ambientBloc.add(const ShivAIEvent.createConversation());
    } else {
      final freshBloc = getIt<ShivAIBloc>()
        ..add(const ShivAIEvent.createConversation());
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<ShivAIBloc>.value(
            value: freshBloc,
            child: ShivChatPage(onDrawerChanged: (_) {}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final top = MediaQuery.of(context).padding.top;

    return BlocListener<NatarajBloc, NatarajState>(
      listenWhen: (prev, curr) =>
          curr.seedChatParagraph != null &&
          curr.seedChatParagraph != prev.seedChatParagraph,
      listener: (context, state) {
        final paragraph = state.seedChatParagraph;
        if (paragraph != null) {
          _openSeededChat(context, paragraph);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceContainerLowest,
        drawer: const NatarajDrawer(),
        onDrawerChanged: widget.onDrawerChanged,
        body: Builder(
          builder: (ctx) => Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              _NatarajHeader(
                top: top,
                onLogoTap: () => Scaffold.of(ctx).openDrawer(),
                onNewChat: () => _onNewChat(ctx),
              ),

              // ── Revisiting banner ───────────────────────────────────────────
              BlocSelector<NatarajBloc, NatarajState, bool>(
                selector: (s) => s.resurfacing,
                builder: (_, resurfacing) {
                  if (!resurfacing) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color:
                        AppColors.secondaryContainer.withValues(alpha: 0.45),
                    child: Text(
                      l10n.natarajRevisitingHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),

              // ── Body ────────────────────────────────────────────────────────
              Expanded(
                child: BlocConsumer<NatarajBloc, NatarajState>(
                  listenWhen: (prev, curr) =>
                      prev.status != curr.status,
                  listener: (context, state) {
                    if (state.status == NatarajStatus.error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.natarajGenerateErrorSnack),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    return switch (state.status) {
                      NatarajStatus.loading =>
                        _LoadingBody(label: l10n.natarajGenerating),
                      // Defense-in-depth: `ready` should always carry a card,
                      // but if a transient emit leaves it null, show loading
                      // rather than crash on `currentCard!` in _DeckBody.
                      NatarajStatus.ready => state.currentCard == null
                          ? _LoadingBody(label: l10n.natarajGenerating)
                          : _DeckBody(
                              state: state,
                              cardController: _cardController,
                              coachDismissed: _coachDismissed,
                              onCoachDismiss: () {
                                getIt<SetNatarajCoachSeenUseCase>().call(true);
                                setState(() => _coachDismissed = true);
                              },
                            ),
                      NatarajStatus.needsMoreNotes ||
                      NatarajStatus.exhausted =>
                        NatarajEmptyState(
                          status: state.status,
                          onAddNotes: () {
                            context.pushNamed(AppRoutes.graph);
                          },
                        ),
                      NatarajStatus.error => _ErrorBody(
                          onRetry: () => context
                              .read<NatarajBloc>()
                              .add(NatarajEvent.loadDeck(state.manasIds)),
                          onChangeModel: () =>
                              context.pushNamed(AppRoutes.aiModelSelection),
                        ),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Header ────────────────────────────────────────────────────────────────────

class _NatarajHeader extends StatelessWidget {
  const _NatarajHeader({
    required this.top,
    required this.onLogoTap,
    required this.onNewChat,
  });

  final double top;
  final VoidCallback onLogoTap;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: top + 10,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // SHIV logo — tap to open the drawer (matches the Shiv chat page).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLogoTap,
            child: SvgPicture.asset(
              'assets/images/tabs/shiva.svg',
              height: 30,
              colorFilter: const ColorFilter.mode(
                AppColors.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ),
          const Spacer(),
          // New chat button
          Tooltip(
            message: l10n.natarajNewChatTooltip,
            child: InkWell(
              onTap: onNewChat,
              borderRadius: BorderRadius.circular(99),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading body ──────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DropLoadingIndicator(),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Deck body (ready state) ───────────────────────────────────────────────────

class _DeckBody extends StatelessWidget {
  const _DeckBody({
    required this.state,
    required this.cardController,
    required this.coachDismissed,
    required this.onCoachDismiss,
  });

  final NatarajState state;
  final NatarajCardController cardController;
  final bool coachDismissed;
  final VoidCallback onCoachDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<NatarajBloc>();
    final card = state.currentCard!;
    final showCoach = state.showCoach && !coachDismissed;
    // ShivPage overlays the FloatingNav at bottom:0 on top of this deck, so the
    // action buttons must sit above it. Reserve the nav's height (~56) + the
    // bottom safe-area inset + a small gap, or the buttons hide behind the nav.
    final navClearance = MediaQuery.of(context).padding.bottom + 64;

    return Stack(
      children: [
        // Main card + edge labels
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Edge labels — static (Offset.zero = no live-drag at page level;
                      // the card animates drag internally).
                      const NatarajEdgeLabels(drag: Offset.zero),
                      // Swipe card — sized to its content. Wrapped in a scroll
                      // view so a long note grows past the screen and scrolls
                      // instead of overflowing; ConstrainedBox(minHeight) keeps
                      // a short card centered.
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          // NeverScrollable: the card grows to its content and a
                          // too-long card clips (no crash), but the scroll view
                          // does NOT absorb vertical drags — so the card's 4-way
                          // swipe (↑ publish / ↓ discuss) keeps working.
                          physics: const NeverScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: NatarajCardWidget(
                                card: card,
                                peek: state.nextCard,
                                controller: cardController,
                                onSwipe: (dir) =>
                                    bloc.add(NatarajEvent.swipeCard(dir)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Fallback action buttons (4 swipe directions). Routed through the
              // card controller so a tap flies the card off in that direction —
              // identical to a swipe — instead of advancing the deck instantly.
              _FallbackButtons(
                onPublish: () => cardController.swipe(NatarajDirection.up),
                onDraft: () => cardController.swipe(NatarajDirection.right),
                onDiscard: () => cardController.swipe(NatarajDirection.left),
                onDiscuss: () => cardController.swipe(NatarajDirection.down),
                l10n: l10n,
              ),
              SizedBox(height: navClearance),
            ],
          ),
        ),

        // Coach overlay (shown once on first open)
        if (showCoach)
          Positioned.fill(
            child: NatarajCoachOverlay(onDismiss: onCoachDismiss),
          ),
      ],
    );
  }
}

// ── Fallback action buttons ───────────────────────────────────────────────────

class _FallbackButtons extends StatelessWidget {
  const _FallbackButtons({
    required this.onPublish,
    required this.onDraft,
    required this.onDiscard,
    required this.onDiscuss,
    required this.l10n,
  });

  final VoidCallback onPublish;
  final VoidCallback onDraft;
  final VoidCallback onDiscard;
  final VoidCallback onDiscuss;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.close_rounded,
            label: l10n.natarajEdgeDiscard,
            color: AppColors.error,
            onTap: onDiscard,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.natarajEdgeDiscuss,
            color: AppColors.primary,
            onTap: onDiscuss,
          ),
          _ActionButton(
            icon: Icons.bookmark_border_rounded,
            label: l10n.natarajEdgeDraft,
            color: AppColors.secondary,
            onTap: onDraft,
          ),
          _ActionButton(
            icon: Icons.publish_rounded,
            label: l10n.natarajEdgePublish,
            color: AppColors.tertiary,
            onTap: onPublish,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry, required this.onChangeModel});
  final VoidCallback onRetry;
  final VoidCallback onChangeModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Generation failed — the dominant cause is the on-device model failing to
    // run (e.g. a model too heavy for this device). Point the user at model
    // selection rather than a bare retry, so it's never mistaken for the
    // "exhausted / add notes" state.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✦',
              style: TextStyle(fontSize: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.natarajModelErrorTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.natarajModelErrorBody,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onChangeModel,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: Text(
                l10n.aiSelectModel,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.natarajRetry),
            ),
          ],
        ),
      ),
    );
  }
}
