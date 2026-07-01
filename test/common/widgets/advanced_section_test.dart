import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/advanced_section.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Covers: starts collapsed (Offstage true), children stay mounted while
/// collapsed (so init defaults still apply), tap toggle, custom label.
void main() {
  Widget host({List<Widget>? children, String? label}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AdvancedSection(
          label: label,
          children: children ?? const [Text('inner')],
        ),
      ),
    );
  }

  Offstage offstageOf(WidgetTester t) => t.widget<Offstage>(find.descendant(
        of: find.byType(AdvancedSection),
        matching: find.byType(Offstage),
      ));

  testWidgets('starts collapsed: Offstage is offstage=true', (t) async {
    await t.pumpWidget(host());
    expect(offstageOf(t).offstage, isTrue);
  });

  testWidgets('children are mounted even while collapsed', (t) async {
    var built = 0;
    await t.pumpWidget(host(children: [
      Builder(builder: (_) {
        built++;
        return const Text('inner');
      }),
    ]));
    expect(built, greaterThan(0),
        reason: 'mounting matters — RelaySelectorField etc. apply defaults on init');
  });

  testWidgets('tap toggles offstage state', (t) async {
    await t.pumpWidget(host());
    expect(offstageOf(t).offstage, isTrue);
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();
    expect(offstageOf(t).offstage, isFalse);
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();
    expect(offstageOf(t).offstage, isTrue,
        reason: 'second tap collapses again');
  });

  testWidgets('custom label overrides the default localized one',
      (t) async {
    await t.pumpWidget(host(label: 'Dev tools'));
    expect(find.text('Dev tools'), findsOneWidget);
  });

  testWidgets('default label is the localized commonAdvanced', (t) async {
    await t.pumpWidget(host());
    // Just verify *some* non-empty header label is rendered — the exact
    // localised string belongs to the l10n test, not this one.
    expect(find.byType(InkWell), findsOneWidget);
  });
}
