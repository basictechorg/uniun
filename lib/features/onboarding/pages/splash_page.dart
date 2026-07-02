import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

/// Flutter splash screen — shown immediately after native splash while the
/// active-user check runs, then navigates to WelcomePage (no identity) or
/// HomePage (already logged in).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _boot();
  }

  Future<void> _boot() async {
    // Auth check: if a user key exists → go straight to home. On any failure,
    // fall back to onboarding rather than leaving the user stranded on splash.
    bool hasUser = false;
    try {
      final result = await getIt<GetActiveUserUseCase>().call();
      hasUser = result.isRight();
    } catch (_) {
      hasUser = false;
    }
    if (!mounted) return;

    context.goNamed(hasUser ? AppRoutes.home : AppRoutes.welcome);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sized to match the native launch splash icon (the Android 12
              // system shrinks/masks android12splash well below its authored
              // 256dp). The mark glyph fills ~82% of its box, so 150 → ~123px
              // visible. Nudge this single value if it still doesn't line up.
              SvgPicture.asset(
                'assets/images/uniun-logo-mark.svg',
                width: 150,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
