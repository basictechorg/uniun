import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Covers: chevron icon, localized tooltip, custom onPressed override,
/// color override, default onPressed is non-null.
void main() {
  testWidgets('renders an iOS-style chevron icon', (t) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(leading: UniunBackButton(onPressed: () {})),
        body: const SizedBox(),
      ),
    ));
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
  });

  testWidgets('custom onPressed wins over default pop', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(leading: UniunBackButton(onPressed: () => taps++)),
      ),
    ));
    await t.tap(find.byType(UniunBackButton));
    expect(taps, 1);
  });

  testWidgets('renders a tooltip from l10n', (t) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(leading: UniunBackButton(onPressed: () {})),
      ),
    ));
    final tooltip = t.widget<Tooltip>(find.descendant(
      of: find.byType(UniunBackButton),
      matching: find.byType(Tooltip),
    ));
    expect(tooltip.message, isNotNull);
    expect(tooltip.message!.isNotEmpty, isTrue);
  });

  testWidgets('color override propagates to the icon', (t) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          leading: UniunBackButton(onPressed: () {}, color: Colors.red),
        ),
      ),
    ));
    final icon = t.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new));
    expect(icon.color, Colors.red);
  });

  testWidgets('default onPressed is non-null (delegates to context.pop)',
      (t) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(leading: const UniunBackButton()),
      ),
    ));
    final button = t.widget<IconButton>(find.descendant(
      of: find.byType(UniunBackButton),
      matching: find.byType(IconButton),
    ));
    expect(button.onPressed, isNotNull,
        reason: 'no custom onPressed → falls back to context.pop()');
  });
}
