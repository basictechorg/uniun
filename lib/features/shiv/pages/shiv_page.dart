import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/floating_nav.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/features/shiv/chat/bloc/shiv_ai_bloc.dart';
import 'package:uniun/features/shiv/chat/pages/shiv_chat_page.dart';
import 'package:uniun/features/shiv/nataraj/pages/nataraj_deck_page.dart';
import 'package:uniun/features/shiv/model_select/pages/ai_model_selection_page.dart';

/// Shiv AI assistant tab root.
///
/// Provides the [ShivAIBloc], loads conversations on mount, then:
/// - If no conversation is active → [NatarajDeckPage] (swipe-deck home).
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
            left: 0,
            right: 0,
            bottom: 0,
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
        child: DropLoadingIndicator(),
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
        return NatarajDeckPage(onDrawerChanged: widget.onDrawerChanged);
      },
    );
  }
}
