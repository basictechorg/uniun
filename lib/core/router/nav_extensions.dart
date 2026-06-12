import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/router/app_routes.dart';

/// Navigation helpers that keep deep links from black-screening.
///
/// A `?dl=1` deep link opens its target as the navigator *root* — go_router
/// resolves an external link with `go()` semantics, which replaces the whole
/// stack — so a plain `Navigator.pop()` on such a page leaves an empty
/// navigator (a black screen). Every back/close action on a deep-linkable page
/// should pop *only when there is somewhere to go back to*, and otherwise land
/// on a real page. These helpers are the single source of truth for that rule.
extension SafeNavX on BuildContext {
  /// Pops the current route if possible, otherwise runs [fallback] (e.g.
  /// navigate to a concrete destination instead of an empty navigator).
  void popOr(VoidCallback fallback) {
    final navigator = Navigator.of(this);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      fallback();
    }
  }

  /// Pops the current route if possible, otherwise resets to the home route.
  /// Use this for the back button on any deep-linkable page.
  void popOrHome() => popOr(() => GoRouter.of(this).goNamed(AppRoutes.home));
}
