import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/features/settings/widgets/media_row.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Covers: MediaRow renders l10n label + subtitle + photo_library icon, and
/// tap pushes the mediaGallery named route.
void main() {
  Widget host({required GoRouter router}) => MaterialApp.router(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        routerConfig: router,
      );

  testWidgets('renders l10n label + subtitle + gallery icon', (t) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: MediaRow())),
      GoRoute(
        path: '/media',
        name: AppRoutes.mediaGallery,
        builder: (_, __) => const Scaffold(body: Text('gallery')),
      ),
    ]);
    await t.pumpWidget(host(router: router));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.storageMediaRow), findsOneWidget);
    expect(find.text(l10n.storageMediaRowSubtitle), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets('tap pushes the mediaGallery route', (t) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: MediaRow())),
      GoRoute(
        path: '/media',
        name: AppRoutes.mediaGallery,
        builder: (_, __) => const Scaffold(body: Text('gallery-page')),
      ),
    ]);
    await t.pumpWidget(host(router: router));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await t.tap(find.text(l10n.storageMediaRow));
    await t.pumpAndSettle();
    expect(find.text('gallery-page'), findsOneWidget);
  });
}
