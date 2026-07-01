import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/note_card/expandable_note_text.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Expand/collapse state machine: toggle visibility above collapsedMaxChars,
/// flip on tap, action colour propagation, threshold boundary.
void main() {
  Widget host({required String text, int max = 280, Color? actionColor}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ExpandableNoteText(
          text: text,
          style: const TextStyle(fontSize: 15),
          collapsedMaxChars: max,
          actionColor: actionColor,
        ),
      ),
    );
  }

  Future<String> readMoreLabel() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    return l10n.actionReadMore;
  }

  Future<String> readLessLabel() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    return l10n.actionReadLess;
  }

  testWidgets('short text: no toggle is rendered', (t) async {
    await t.pumpWidget(host(text: 'short', max: 280));
    expect(find.text(await readMoreLabel()), findsNothing);
    expect(find.text(await readLessLabel()), findsNothing);
  });

  testWidgets('long text: "Read more" toggle is rendered', (t) async {
    await t.pumpWidget(host(text: 'x' * 500, max: 280));
    expect(find.text(await readMoreLabel()), findsOneWidget);
  });

  testWidgets('tap "Read more" flips to "Read less"', (t) async {
    await t.pumpWidget(host(text: 'x' * 500, max: 280));
    await t.tap(find.text(await readMoreLabel()));
    await t.pumpAndSettle();
    expect(find.text(await readLessLabel()), findsOneWidget);
  });

  testWidgets('tap "Read less" collapses again', (t) async {
    await t.pumpWidget(host(text: 'x' * 500, max: 280));
    await t.tap(find.text(await readMoreLabel()));
    await t.pumpAndSettle();
    await t.tap(find.text(await readLessLabel()));
    await t.pumpAndSettle();
    expect(find.text(await readMoreLabel()), findsOneWidget);
  });

  testWidgets('action colour propagates onto the toggle text', (t) async {
    await t.pumpWidget(host(
      text: 'y' * 500,
      max: 280,
      actionColor: Colors.deepPurple,
    ));
    final txt = t.widget<Text>(find.text(await readMoreLabel()));
    expect(txt.style?.color, Colors.deepPurple);
  });

  testWidgets('exactly at threshold: no overflow', (t) async {
    // length == max: not greater-than, so no toggle.
    await t.pumpWidget(host(text: 'z' * 50, max: 50));
    expect(find.text(await readMoreLabel()), findsNothing);
  });

  testWidgets('threshold + 1: overflow', (t) async {
    await t.pumpWidget(host(text: 'z' * 51, max: 50));
    expect(find.text(await readMoreLabel()), findsOneWidget);
  });
}
