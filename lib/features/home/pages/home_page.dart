import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/vishnu/bloc/vishnu_feed_bloc.dart';
import 'package:uniun/features/vishnu/pages/vishnu_feed_page.dart';
import 'package:uniun/features/shiv/pages/shiv_page.dart';
import 'package:uniun/gateway/gateway.dart';

/// App shell — standard Flutter Scaffold + floating pill nav.
///   0 = Vishnu (feed)
///   1 = Brahma (graph — pushed as a full-screen route)
///   2 = Shiv   (AI assistant)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final VishnuFeedBloc _vishnuFeedBloc;

  // 0 = Vishnu, 2 = Shiv — index 1 navigates away so it never lives in the stack.
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _vishnuFeedBloc = getIt<VishnuFeedBloc>()..add(const FeedOpenedEvent());
    GatewayBootstrap.start();
  }

  @override
  void dispose() {
    _vishnuFeedBloc.close();
    super.dispose();
  }

  Future<void> _switchTab(int i) async {
    if (i == 1) {
      // Brahma is a pushed route, not a stack tab. Its FloatingNav can pop
      // back with an explicit tab index; pop on publish returns null → land
      // on Vishnu so the user sees their new note.
      final targetTab = await context.pushNamed<Object?>(AppRoutes.graph);
      _vishnuFeedBloc.add(const RefreshFeedEvent());
      final destination =
          targetTab is int && targetTab != 1 ? targetTab : 0;
      if (mounted) setState(() => _currentIndex = destination);
      return;
    }
    if (i == 0 && _currentIndex != 0) {
      _vishnuFeedBloc.add(const RefreshFeedEvent());
    }
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VishnuFeedBloc>.value(value: _vishnuFeedBloc),
      ],
      child: Scaffold(
        backgroundColor: AppColors.surfaceContainerLowest,
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _currentIndex == 2 ? 1 : 0,
          children: [
            VishnuFeedPage(
              currentIndex: _currentIndex,
              onSwitchTab: _switchTab,
            ),
            ShivPage(
              currentIndex: _currentIndex,
              onSwitchTab: _switchTab,
            ),
          ],
        ),
      ),
    );
  }
}
