import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/floating_nav.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/chat/pages/shiv_chat_page.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_history_drawer.dart';
import 'package:uniun/features/shiv/model_select/pages/ai_model_selection_page.dart';
import 'package:uniun/features/shiv/services/ai_model_runner.dart';

/// Shiv AI assistant tab root.
///
/// Provides the [ShivAIBloc], loads conversations on mount, then:
/// - If no conversation is active → landing screen with "New Chat" + history button.
/// - If a conversation is active → [ShivChatPage].
///
/// Redirects to the AI model selection screen if no model is installed.
class ShivPage extends StatefulWidget {
  const ShivPage({
    super.key,
    required this.currentIndex,
    required this.onSwitchTab,
  });

  final int currentIndex;
  final Future<void> Function(int) onSwitchTab;

  @override
  State<ShivPage> createState() => _ShivPageState();
}

class _ShivPageState extends State<ShivPage> {
  bool? _hasModel;
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkModel());
  }

  Future<void> _checkModel() async {
    if (!mounted) return;
    final result = await getIt<GetActiveAIModelUseCase>().call();
    final hasModel = result.fold((_) => false, (m) => m != null);
    if (mounted) {
      setState(() => _hasModel = hasModel);
    }
  }

  void _onDrawerChanged(bool isOpen) {
    if (_drawerOpen != isOpen) setState(() => _drawerOpen = isOpen);
  }

  @override
  Widget build(BuildContext context) {
    // Show model selection if no model exists.
    // AIModelSelectionPage uses Navigator.maybePop() so PopScope intercepts it.
    // result == true  → model downloaded, re-check and stay on Shiv.
    // result == null  → back pressed, go to Vishnu.
    if (_hasModel == false) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            if (result == true) {
              await _checkModel();
            } else {
              widget.onSwitchTab(0);
            }
          }
        },
        child: const AIModelSelectionPage(),
      );
    }

    // Show Shiv UI once model exists — FloatingNav overlaid via Stack
    if (_hasModel == true) {
      return Stack(
        children: [
          BlocProvider(
            create: (_) =>
                getIt<ShivAIBloc>()..add(const ShivAIEvent.loadConversations()),
            child: _ShivRoot(
              currentIndex: widget.currentIndex,
              onDrawerChanged: _onDrawerChanged,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: KeyboardVisibilityBuilder(
              builder: (context, isKeyboardVisible) => AnimatedSlide(
                offset: (isKeyboardVisible || _drawerOpen)
                    ? const Offset(0, 1.5)
                    : Offset.zero,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: FloatingNav(
                  currentIndex: widget.currentIndex,
                  onTap: widget.onSwitchTab,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Loading state
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Watches the bottom-nav index and pings the bloc when the user enters or
/// leaves the Shiv tab. We can't piggy-back on widget disposal because
/// [HomePage] uses an [IndexedStack] — ShivPage stays mounted on every tab.
const int _kShivTabIndex = 2;

class _ShivRoot extends StatefulWidget {
  const _ShivRoot({
    required this.currentIndex,
    required this.onDrawerChanged,
  });
  final int currentIndex;
  final ValueChanged<bool> onDrawerChanged;

  @override
  State<_ShivRoot> createState() => _ShivRootState();
}

class _ShivRootState extends State<_ShivRoot> {
  @override
  void initState() {
    super.initState();
    if (widget.currentIndex == _kShivTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ShivAIBloc>().onEnterShivTab();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ShivRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasShiv = oldWidget.currentIndex == _kShivTabIndex;
    final isShiv = widget.currentIndex == _kShivTabIndex;
    if (wasShiv == isShiv) return;
    if (isShiv) {
      context.read<ShivAIBloc>().onEnterShivTab();
    } else {
      context.read<ShivAIBloc>().onLeaveShivTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShivAIBloc, ShivAIState>(
      buildWhen: (prev, curr) =>
          (prev.activeConversation == null) !=
          (curr.activeConversation == null),
      builder: (context, state) {
        if (state.activeConversation != null) {
          return ShivChatPage(onDrawerChanged: widget.onDrawerChanged);
        }
        return _ShivLanding(onDrawerChanged: widget.onDrawerChanged);
      },
    );
  }
}

// ── Landing screen (no active conversation) ───────────────────────────────────

class _ShivLanding extends StatelessWidget {
  const _ShivLanding({required this.onDrawerChanged});
  final ValueChanged<bool> onDrawerChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      drawer: const ShivHistoryDrawer(),
      onDrawerChanged: onDrawerChanged,
      // Builder gives a context that IS a descendant of this Scaffold,
      // so Scaffold.of(ctx).openDrawer() targets the right Scaffold.
      body: Builder(
        builder: (ctx) => Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 8,
              top: top + 12,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                // SHIV icon
                SvgPicture.asset(
                  'assets/images/tabs/shiva.svg',
                  width: 36,
                  height: 36,
                  colorFilter: const ColorFilter.mode(
                    AppColors.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
                const Spacer(),
                // History — ctx is a descendant of this Scaffold so openDrawer works
                _HeaderIcon(
                  icon: Icons.history_rounded,
                  tooltip: l10n.shivConversationsTooltip,
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                ),
                // Tree (disabled on landing — no active conversation)
                _HeaderIcon(
                  icon: Icons.account_tree_outlined,
                  tooltip: l10n.shivBranchTreeTooltip,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
          // RAG initializing banner
          BlocSelector<ShivAIBloc, ShivAIState, bool>(
            selector: (s) => s.isRagInitializing,
            builder: (context, isInitializing) {
              if (!isInitializing) return const SizedBox.shrink();
              final l10n = AppLocalizations.of(context)!;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.aiEmbeddingSetupInProgress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Body
          Expanded(
            child: BlocBuilder<ShivAIBloc, ShivAIState>(
              builder: (context, state) {
                return _LandingBody(
                  conversationCount: state.conversations.length,
                  onNewChat: () {
                    // Check if model is active before creating conversation
                    if (!getIt<AIModelRunner>().hasActiveModel) {
                      Navigator.of(context).pushNamed(AppRoutes.aiModelSelection);
                    } else {
                      context.read<ShivAIBloc>().add(
                        const ShivAIEvent.createConversation(),
                      );
                    }
                  },
                  onHistory: () => Scaffold.of(ctx).openDrawer(),
                );
              },
            ),
          ),
        ],
        ), // close Builder
      ),
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody({
    required this.conversationCount,
    required this.onNewChat,
    required this.onHistory,
  });

  final int conversationCount;
  final VoidCallback onNewChat;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Halo avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer.withValues(alpha: 0.25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.shivName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.shivLandingBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              // New chat CTA
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: onNewChat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          color: AppColors.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.shivNewConversation,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (conversationCount > 0) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onHistory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.shivViewConversations(conversationCount),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
