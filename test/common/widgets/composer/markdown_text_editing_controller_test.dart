import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/composer/markdown_text_editing_controller.dart';

import '../../../_helpers/fixtures.dart';

/// `text` stays raw markdown; `buildTextSpan` produces a styled tree.
String _flatten(TextSpan s) {
  final buf = StringBuffer();
  s.visitChildren((sp) {
    if (sp is TextSpan && sp.text != null) buf.write(sp.text);
    return true;
  });
  return buf.toString();
}

void main() {
  late MarkdownTextEditingController c;

  setUp(() {
    c = MarkdownTextEditingController();
  });

  Future<TextSpan> buildAt(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (b) {
        ctx = b;
        return const SizedBox.shrink();
      }),
    ));
    return c.buildTextSpan(
      context: ctx,
      style: const TextStyle(fontSize: 15),
      withComposing: false,
    );
  }

  testWidgets('empty text yields a leaf TextSpan with no children', (t) async {
    c.text = '';
    final span = await buildAt(t);
    expect(span.text, '');
    expect(span.children, anyOf(isNull, isEmpty));
  });

  testWidgets('underlying text is never mutated by build', (t) async {
    c.text = '**bold** and *i* and `c`';
    await buildAt(t);
    expect(c.text, '**bold** and *i* and `c`',
        reason: 'publish path depends on raw markdown surviving');
  });

  testWidgets('flat-text round trip preserves every character', (t) async {
    c.text = '**bold** and _italic_ and `code` and [a](https://x.com)';
    final span = await buildAt(t);
    expect(_flatten(span), c.text);
  });

  testWidgets('heading is recognised: level 1', (t) async {
    c.text = '# Title';
    final span = await buildAt(t);
    expect(_flatten(span), '# Title');
  });

  testWidgets('multiple lines compose: heading then plain', (t) async {
    c.text = '## H\nbody';
    final span = await buildAt(t);
    expect(_flatten(span), '## H\nbody');
  });

  testWidgets('snake_case is NOT italicised (boundary rule)', (t) async {
    c.text = 'my_file_name';
    final span = await buildAt(t);
    expect(_flatten(span), 'my_file_name');
  });

  testWidgets('bold takes priority over italic (greedy)', (t) async {
    c.text = '**bold _inside_ end**';
    final span = await buildAt(t);
    expect(_flatten(span), '**bold _inside_ end**');
  });

  testWidgets('bare URL renders untouched in the span', (t) async {
    c.text = 'see https://uniun.in/x for more';
    final span = await buildAt(t);
    expect(_flatten(span), 'see https://uniun.in/x for more');
  });

  testWidgets('caret outside marker paints it transparent', (t) async {
    c.text = 'before **bold** after';
    c.selection = const TextSelection.collapsed(offset: 0); // way before
    final span = await buildAt(t);
    // Collect every leaf with text == '**' and inspect its color.
    final markerColors = <Color?>[];
    span.visitChildren((sp) {
      if (sp is TextSpan && sp.text == '**') {
        markerColors.add(sp.style?.color);
      }
      return true;
    });
    expect(markerColors, isNotEmpty);
    expect(
      markerColors.every((c) => c == Colors.transparent),
      isTrue,
      reason: 'caret outside region → markers are hidden (transparent)',
    );
  });

  testWidgets('caret inside marker reveals it as a visible color', (t) async {
    c.text = '**bold**';
    c.selection = const TextSelection.collapsed(offset: 4); // inside "bold"
    final span = await buildAt(t);
    Color? markerColor;
    span.visitChildren((sp) {
      if (sp is TextSpan && sp.text == '**' && markerColor == null) {
        markerColor = sp.style?.color;
      }
      return true;
    });
    expect(markerColor, isNot(Colors.transparent),
        reason: 'caret inside region → markers visible (dim grey)');
  });

  testWidgets('link span carries the underline decoration', (t) async {
    c.text = '[label](https://x)';
    final span = await buildAt(t);
    var foundUnderline = false;
    span.visitChildren((sp) {
      if (sp is TextSpan && sp.text == 'label') {
        if (sp.style?.decoration == TextDecoration.underline) {
          foundUnderline = true;
        }
      }
      return true;
    });
    expect(foundUnderline, isTrue);
  });

  // ── Edge cases ───────────────────────────────────────────────────────────

  group('text fidelity', () {
    testWidgets('long content survives unmutated', (t) async {
      c.text = Content.veryLong();
      await buildAt(t);
      expect(c.text, Content.veryLong());
    });

    testWidgets('emoji content survives', (t) async {
      c.text = Content.emoji;
      await buildAt(t);
      expect(c.text, Content.emoji);
    });

    testWidgets('RTL content survives', (t) async {
      c.text = Content.rtl;
      await buildAt(t);
      expect(c.text, Content.rtl);
    });

    testWidgets('mixed-marker round-trip preserves text', (t) async {
      c.text = Content.mixedInline;
      final span = await buildAt(t);
      expect(_flatten(span), c.text);
    });
  });

  group('overlap resolution', () {
    testWidgets('bold claims first; italic inside is not re-tokenised',
        (t) async {
      c.text = '**bold _inside_ end**';
      final span = await buildAt(t);
      expect(_flatten(span), '**bold _inside_ end**');
    });

    testWidgets('URL inside a link url slot is not double-rendered',
        (t) async {
      c.text = '[label](https://x.com/y)';
      final span = await buildAt(t);
      expect(_flatten(span), '[label](https://x.com/y)');
    });

    testWidgets('URL inside inline code stays plain', (t) async {
      c.text = '`https://example.com`';
      final span = await buildAt(t);
      expect(_flatten(span), '`https://example.com`');
    });
  });

  group('heading matching', () {
    testWidgets('# only matches at line start', (t) async {
      c.text = 'inline # not a heading';
      final span = await buildAt(t);
      expect(_flatten(span), 'inline # not a heading');
    });

    testWidgets('heading-only line', (t) async {
      c.text = '## h2';
      final span = await buildAt(t);
      expect(_flatten(span), '## h2');
    });

    testWidgets('heading on a middle line', (t) async {
      c.text = 'intro\n# title\nbody';
      final span = await buildAt(t);
      expect(_flatten(span), 'intro\n# title\nbody');
    });

    testWidgets('h4+ is not recognised (only 1-3)', (t) async {
      c.text = '#### still inline';
      final span = await buildAt(t);
      expect(_flatten(span), '#### still inline');
    });
  });

  group('caret edge cases', () {
    testWidgets('invalid selection (caret = -1) hides all markers',
        (t) async {
      c.text = '**a** _b_ `c`';
      c.selection = const TextSelection.collapsed(offset: -1);
      final span = await buildAt(t);
      final markers = <Color?>[];
      span.visitChildren((sp) {
        if (sp is TextSpan &&
            (sp.text == '**' || sp.text == '_' || sp.text == '`')) {
          markers.add(sp.style?.color);
        }
        return true;
      });
      expect(markers, isNotEmpty);
      expect(markers.every((c) => c == Colors.transparent), isTrue);
    });

    testWidgets('caret past end of text does not throw', (t) async {
      c.text = 'short';
      c.selection = const TextSelection.collapsed(offset: 5);
      final span = await buildAt(t);
      expect(_flatten(span), 'short');
    });
  });

  group('boundary conditions', () {
    testWidgets('trailing newline preserved', (t) async {
      c.text = 'a\n';
      final span = await buildAt(t);
      expect(_flatten(span), 'a\n');
    });

    testWidgets('only whitespace', (t) async {
      c.text = '   ';
      final span = await buildAt(t);
      expect(_flatten(span), '   ');
    });

    testWidgets('only `*` chars', (t) async {
      c.text = '***';
      final span = await buildAt(t);
      expect(_flatten(span), '***');
    });

    testWidgets('only `_` chars', (t) async {
      c.text = '___';
      final span = await buildAt(t);
      expect(_flatten(span), '___');
    });
  });
}
