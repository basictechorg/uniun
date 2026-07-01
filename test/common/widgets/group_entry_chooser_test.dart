import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/group_entry_chooser.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Covers: title/subtitle/labels render, hero icon, join/create callbacks,
/// leading back button.
void main() {
  Widget host({
    VoidCallback? onJoin,
    VoidCallback? onCreate,
    IconData icon = Icons.tag_rounded,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => GroupEntryChooser(
            title: 'Title',
            subtitle: 'Subtitle copy',
            joinLabel: 'Join Group',
            createLabel: 'Create Group',
            icon: icon,
            onJoin: onJoin ?? () {},
            onCreate: onCreate ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders title, subtitle, and both action labels', (t) async {
    await t.pumpWidget(host());
    expect(find.text('Title'), findsAtLeastNWidgets(1));
    expect(find.text('Subtitle copy'), findsOneWidget);
    expect(find.text('Join Group'), findsOneWidget);
    expect(find.text('Create Group'), findsOneWidget);
  });

  testWidgets('renders the hero icon passed in', (t) async {
    await t.pumpWidget(host(icon: Icons.shield_rounded));
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
  });

  testWidgets('tapping the join card invokes onJoin', (t) async {
    var joined = 0;
    await t.pumpWidget(host(onJoin: () => joined++));
    await t.tap(find.text('Join Group'));
    expect(joined, 1);
  });

  testWidgets('tapping the create card invokes onCreate', (t) async {
    var created = 0;
    await t.pumpWidget(host(onCreate: () => created++));
    await t.tap(find.text('Create Group'));
    expect(created, 1);
  });

  testWidgets('renders a leading back button in the app bar', (t) async {
    await t.pumpWidget(host());
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
  });
}
