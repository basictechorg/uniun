import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/markdown/note_markdown_body.dart';

/// Covers: MarkdownBody renders, bare URLs are host-shortened before parse,
/// www. stripped, already-bracketed links are not double-wrapped, linkColor
/// flows into styleSheet, onTap → onTapText, empty content survives.
void main() {
  testWidgets('renders a MarkdownBody', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: NoteMarkdownBody(content: 'plain text')),
    ));
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('bare https URL is shortened to host in display text',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(content: 'go to https://uniun.in/some/path'),
      ),
    ));
    final body = t.widget<MarkdownBody>(find.byType(MarkdownBody));
    // The transform happens on `data` before parsing — the shortened markdown
    // `[uniun.in](https://uniun.in/some/path)` is what reaches the parser.
    expect(body.data, contains('[uniun.in]'));
    expect(body.data, contains('(https://uniun.in/some/path)'));
  });

  testWidgets('strips www. when host-shortening URLs', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(content: 'https://www.example.com/x'),
      ),
    ));
    final body = t.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(body.data, contains('[example.com]'));
  });

  testWidgets('already-bracketed link is NOT rewritten (no double-wrap)',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(content: '[docs](https://uniun.in/x)'),
      ),
    ));
    final body = t.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(body.data, '[docs](https://uniun.in/x)');
  });

  testWidgets('http (non-https) URLs are also host-shortened', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(content: 'http://legacy.example/'),
      ),
    ));
    final body = t.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(body.data, contains('[legacy.example]'));
  });

  testWidgets('linkColor flows into the styleSheet', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(
          content: '[a](https://x)',
          linkColor: Colors.amber,
        ),
      ),
    ));
    final body = t.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(body.styleSheet?.a?.color, Colors.amber);
  });

  testWidgets('onTap is wired to onTapText', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(
          content: 'tap me',
          onTap: () => taps++,
        ),
      ),
    ));
    final body = t.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(body.onTapText, isNotNull);
    body.onTapText!();
    expect(taps, 1);
  });

  testWidgets('empty content does not crash and still renders a body',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: NoteMarkdownBody(content: '')),
    ));
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
