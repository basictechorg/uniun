import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/note_card/expandable_note_text.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Regression guard for two requirements that fight in the gesture arena:
///   1. Tapping a note body opens the thread (the card's `onTap`).
///   2. The note body text stays selectable (long-press to copy).
///
/// A selectable markdown body is a `SelectableText.rich` whose recognizer wins
/// the arena and swallows an ancestor `InkWell.onTap`. We keep it selectable
/// and forward a simple tap through `SelectableText.onTap`, so both work.
void main() {
  Widget host({VoidCallback? onTap}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ExpandableNoteText(
          text: 'hello world',
          onTap: onTap,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  testWidgets('body text is rendered selectable', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('a simple tap on the body fires the forwarded onTap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    // Tap directly on the SelectableText — for short content, the
    // ExpandableNoteText widget's centre is in the empty space to the right
    // of the left-aligned column child, which would miss the hit target.
    await tester.tap(find.byType(SelectableText));
    await tester.pump();
    expect(taps, 1);
  });
}
