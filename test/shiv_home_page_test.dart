import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/pages/shiv_home_page.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Verifies the Shiv home landing renders its hero affordances and that each
/// one fires the right callback — `onAsk` (→ new chat), `onSuggest` (→ seeded
/// chat), `onOpenGana`, `onOpenNataraj`. The actual navigation/bloc wiring
/// lives in `_ShivRoot`; here we prove the surface forwards intent correctly.
void main() {
  Widget host({
    VoidCallback? onAsk,
    ValueChanged<String>? onSuggest,
    VoidCallback? onOpenGana,
    VoidCallback? onOpenNataraj,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShivHomePage(
        onDrawerChanged: (_) {},
        onAsk: onAsk ?? () {},
        onSuggest: onSuggest ?? (_) {},
        onOpenGana: onOpenGana ?? () {},
        onOpenNataraj: onOpenNataraj ?? () {},
      ),
    );
  }

  testWidgets('renders the hero headline, ask card, chips and tools',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('How can I help you?'), findsOneWidget);
    expect(find.text('Ask Shiv anything…'), findsOneWidget);
    expect(find.text('Gana'), findsOneWidget);
    expect(find.text('Nataraj'), findsOneWidget);
    expect(find.text('Summarize my week'), findsOneWidget);
    expect(find.text('Connect two ideas'), findsOneWidget);
    expect(find.text('Draft from a note'), findsOneWidget);
  });

  testWidgets('tapping the ask card fires onAsk', (tester) async {
    var asked = 0;
    await tester.pumpWidget(host(onAsk: () => asked++));
    await tester.pump();

    await tester.tap(find.text('Ask Shiv anything…'));
    expect(asked, 1);
  });

  testWidgets('tapping Gana fires onOpenGana', (tester) async {
    var gana = 0;
    await tester.pumpWidget(host(onOpenGana: () => gana++));
    await tester.pump();

    await tester.tap(find.text('Gana'));
    expect(gana, 1);
  });

  testWidgets('tapping Nataraj fires onOpenNataraj', (tester) async {
    var nataraj = 0;
    await tester.pumpWidget(host(onOpenNataraj: () => nataraj++));
    await tester.pump();

    await tester.tap(find.text('Nataraj'));
    expect(nataraj, 1);
  });

  testWidgets('tapping a suggestion fires onSuggest with its text',
      (tester) async {
    String? seeded;
    await tester.pumpWidget(host(onSuggest: (t) => seeded = t));
    await tester.pump();

    await tester.tap(find.text('Connect two ideas'));
    expect(seeded, 'Connect two ideas');
  });
}
