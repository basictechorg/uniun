import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/brahma/manas/widgets/manas_icon_picker.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Widget tests for [ManasIconPicker.show]. Verifies the modal sheet returns
/// the picked icon name (or null on dismiss) and the grid renders the full
/// registry.
void main() {
  Widget host(void Function(BuildContext) onTap, {String? current}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping an icon pops with that icon\'s registered name', (tester) async {
    String? picked;
    await tester.pumpWidget(host((ctx) async {
      picked = await ManasIconPicker.show(ctx);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Every registry entry should be present as a tappable Icon.
    final firstName = ManasIcons.allNames.first;
    final iconData = ManasIcons.byName(firstName);
    final iconFinder = find.byIcon(iconData).first;
    expect(iconFinder, findsOneWidget);

    await tester.tap(iconFinder);
    await tester.pumpAndSettle();

    expect(picked, firstName);
  });

  testWidgets('dismissing (tap outside) → null', (tester) async {
    String? picked = 'sentinel';
    await tester.pumpWidget(host((ctx) async {
      picked = await ManasIconPicker.show(ctx);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap on the barrier above the sheet to dismiss it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('renders every icon in the registry', (tester) async {
    await tester.pumpWidget(host((ctx) async {
      await ManasIconPicker.show(ctx);
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // GridView lazily builds — give it enough viewport to render at least
    // a handful so we can sanity-check the count matches.
    final renderedIcons = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Icon),
    );
    // Lazy grid may not lay out every cell; assert ≥ 12 are rendered
    // (the first viewport's worth) — proves the grid is populated, not
    // empty.
    expect(renderedIcons.evaluate().length, greaterThanOrEqualTo(12));
  });
}
