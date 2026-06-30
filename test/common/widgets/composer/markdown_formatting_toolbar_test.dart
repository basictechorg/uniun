import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/composer/markdown_formatting_toolbar.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Each button's effect on the controller's text + selection.
void main() {
  late TextEditingController c;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MarkdownFormattingToolbar(controller: c),
      ),
    ));
  }

  setUp(() {
    c = TextEditingController();
  });

  tearDown(() => c.dispose());

  group('bold (**…**)', () {
    testWidgets('wraps selected text', (t) async {
      c.text = 'hello world';
      c.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      await pump(t);
      await t.tap(find.byIcon(Icons.format_bold_rounded));
      await t.pump();
      expect(c.text, 'hello **world**');
    });

    testWidgets('no selection: inserts stub at cursor', (t) async {
      c.text = 'abc';
      c.selection = const TextSelection.collapsed(offset: 3);
      await pump(t);
      await t.tap(find.byIcon(Icons.format_bold_rounded));
      await t.pump();
      // For an empty selection, _wrap inserts before+after at the caret and
      // places the caret between them.
      expect(c.text, 'abc****');
      expect(c.selection.baseOffset, 5);
    });
  });

  group('italic (_…_)', () {
    testWidgets('wraps selected text in underscores', (t) async {
      c.text = 'one two three';
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      await pump(t);
      await t.tap(find.byIcon(Icons.format_italic_rounded));
      await t.pump();
      expect(c.text, 'one _two_ three');
    });
  });

  group('inline code (`…`)', () {
    testWidgets('wraps selected text in backticks', (t) async {
      c.text = 'run cmd ok';
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      await pump(t);
      await t.tap(find.byIcon(Icons.code_rounded));
      await t.pump();
      expect(c.text, 'run `cmd` ok');
    });
  });

  group('lists (bulleted / numbered / quote)', () {
    testWidgets('bulleted: prefixes each selected line', (t) async {
      c.text = 'a\nb\nc';
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await pump(t);
      await t.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await t.pump();
      expect(c.text, '- a\n- b\n- c');
    });

    testWidgets('numbered: prefixes each selected line with "1. "', (t) async {
      c.text = 'a\nb';
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      await pump(t);
      await t.tap(find.byIcon(Icons.format_list_numbered_rounded));
      await t.pump();
      expect(c.text, '1. a\n1. b');
    });

    testWidgets('quote: prefixes each selected line with "> "', (t) async {
      c.text = 'a\nb';
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      await pump(t);
      await t.tap(find.byIcon(Icons.format_quote_rounded));
      await t.pump();
      expect(c.text, '> a\n> b');
    });

    testWidgets('no selection + non-empty text: appends newline + prefix',
        (t) async {
      c.text = 'existing';
      await pump(t);
      await t.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await t.pump();
      expect(c.text, 'existing\n- ');
    });
  });

  group('link', () {
    testWidgets('no selection: inserts stub and selects placeholder',
        (t) async {
      c.text = '';
      c.selection = const TextSelection.collapsed(offset: 0);
      await pump(t);
      await t.tap(find.byIcon(Icons.link_rounded));
      await t.pump();
      expect(c.text, '[text](https://)');
      // baseOffset just past '[' selecting 'text'.
      expect(c.selection.baseOffset, 1);
      expect(c.selection.extentOffset, 5);
    });

    testWidgets('with selection: uses selection as label, caret near url',
        (t) async {
      c.text = 'see docs here';
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 8);
      await pump(t);
      await t.tap(find.byIcon(Icons.link_rounded));
      await t.pump();
      expect(c.text, 'see [docs](https://) here');
      // caret lands just inside the closing paren so URL types in.
      expect(c.selection.baseOffset, c.text.indexOf(')'));
    });
  });

  group('heading cycle', () {
    testWidgets('no heading → H1', (t) async {
      c.text = 'Title';
      c.selection = const TextSelection.collapsed(offset: 0);
      await pump(t);
      await t.tap(find.byIcon(Icons.title_rounded));
      await t.pump();
      expect(c.text, '# Title');
    });

    testWidgets('H1 → H2', (t) async {
      c.text = '# Title';
      c.selection = const TextSelection.collapsed(offset: 0);
      await pump(t);
      await t.tap(find.byIcon(Icons.title_rounded));
      await t.pump();
      expect(c.text, '## Title');
    });

    testWidgets('H2 → H3', (t) async {
      c.text = '## T';
      c.selection = const TextSelection.collapsed(offset: 0);
      await pump(t);
      await t.tap(find.byIcon(Icons.title_rounded));
      await t.pump();
      expect(c.text, '### T');
    });

    testWidgets('H3 → none (strip)', (t) async {
      c.text = '### T';
      c.selection = const TextSelection.collapsed(offset: 0);
      await pump(t);
      await t.tap(find.byIcon(Icons.title_rounded));
      await t.pump();
      expect(c.text, 'T');
    });
  });
}
