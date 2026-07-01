import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/floating_nav.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Covers: Vishnu/Brahma/Shiv tap each fire onTap with the right index,
/// renders without crash for each active surface.
void main() {
  Future<void> pump(WidgetTester t, int current,
      Future<void> Function(int) onTap) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FloatingNav(currentIndex: current, onTap: onTap),
        ),
      ),
    ));
  }

  testWidgets('renders Vishnu, Brahma, Shiv labels', (t) async {
    await pump(t, 0, (_) async {});
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.navVishnu), findsOneWidget);
    expect(find.text(l10n.navBrahma), findsNothing,
        reason: 'Brahma is a glyph-only FAB — semantic label only, no Text');
    expect(find.text(l10n.navShiv), findsOneWidget);
  });

  testWidgets('tapping Vishnu fires onTap(0)', (t) async {
    int? lastIndex;
    await pump(t, 1, (i) async => lastIndex = i);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await t.tap(find.text(l10n.navVishnu));
    await t.pump();
    expect(lastIndex, 0);
  });

  testWidgets('tapping Shiv fires onTap(2)', (t) async {
    int? lastIndex;
    await pump(t, 1, (i) async => lastIndex = i);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await t.tap(find.text(l10n.navShiv));
    await t.pump();
    expect(lastIndex, 2);
  });

  testWidgets('tapping the Brahma FAB fires onTap(1)', (t) async {
    int? lastIndex;
    await pump(t, 0, (i) async => lastIndex = i);
    // Tap by semantics label since the FAB is glyph-only.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await t.tap(find.bySemanticsLabel(l10n.navBrahma));
    await t.pump();
    expect(lastIndex, 1);
  });

  testWidgets('renders regardless of which tab is active', (t) async {
    for (final idx in [0, 1, 2]) {
      await pump(t, idx, (_) async {});
      expect(find.byType(FloatingNav), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}
