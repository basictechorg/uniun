import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// `TextEditingController` that paints inline markdown spans (bold / italic /
/// inline code / links / headings) with their syntax markers hidden, so the
/// composer reads as the rendered post — Obsidian-style live preview.
///
/// The underlying [value.text] is untouched — still raw markdown — so the
/// publish path doesn't change. Only the painted [TextSpan] tree is altered:
///   * markers (`**`, `_`, `` ` ``, `[`, `](url)`, `#…` heading prefix) are
///     coloured transparent when the caret sits outside the region, and
///     dimmed grey when the caret is inside it (so the user can find the
///     bounds while editing).
///   * inner content carries the formatted style (bold, italic, monospace,
///     link colour, heading size+weight).
///   * bare URLs render in the link colour (left full-length — the rendered
///     [NoteCard] is responsible for host-only shortening on display).
class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final source = text;
    final caret = selection.isValid ? selection.extentOffset : -1;
    if (source.isEmpty) {
      return TextSpan(style: baseStyle, text: source);
    }

    final children = <InlineSpan>[];

    // Walk line-by-line so heading detection (line-anchored) composes with the
    // inline tokenizer.
    int lineStart = 0;
    while (lineStart <= source.length) {
      final nl = source.indexOf('\n', lineStart);
      final lineEnd = nl < 0 ? source.length : nl;
      final line = source.substring(lineStart, lineEnd);

      final heading = RegExp(r'^(#{1,3}) ').firstMatch(line);
      if (heading != null) {
        final hashes = heading.group(1)!;
        final level = hashes.length;
        final markerLen = hashes.length + 1;
        final caretInLine = caret >= lineStart && caret <= lineEnd;
        final markerStyle = baseStyle.copyWith(
          color: caretInLine ? AppColors.outline : Colors.transparent,
        );
        final headingStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 15) + (4 - level) * 3.0,
          fontWeight: FontWeight.w800,
          height: 1.3,
        );
        children.add(TextSpan(
          text: line.substring(0, markerLen),
          style: markerStyle,
        ));
        children.addAll(_tokenizeInline(
          line.substring(markerLen),
          headingStyle,
          caret - (lineStart + markerLen),
        ));
      } else {
        children.addAll(_tokenizeInline(line, baseStyle, caret - lineStart));
      }

      if (nl < 0) break;
      children.add(const TextSpan(text: '\n'));
      lineStart = nl + 1;
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

// ── Inline tokenizer ───────────────────────────────────────────────────────

enum _MdKind { bold, italic, code, link, url }

class _MdMatch {
  _MdMatch(this.start, this.end, this.kind, this.match);
  final int start;
  final int end;
  final _MdKind kind;
  final RegExpMatch match;
}

/// Order = priority. Bold (`**`) tried before italic (`_`) so `**bold**`
/// isn't mis-tokenised as two italic underscores around `*bold*`.
const _patterns = [
  (_MdKind.bold, r'\*\*(.+?)\*\*'),
  (_MdKind.code, r'`([^`\n]+)`'),
  (_MdKind.link, r'\[([^\]\n]+)\]\(([^)\s]+)\)'),
  (_MdKind.italic, r'(?<![\w*])_([^_\n]+)_(?![\w*])'),
  (_MdKind.url, r'https?://[^\s)]+'),
];

List<InlineSpan> _tokenizeInline(String text, TextStyle base, int caret) {
  final out = <InlineSpan>[];
  if (text.isEmpty) return out;

  final matches = <_MdMatch>[];
  for (final (kind, pattern) in _patterns) {
    for (final m in RegExp(pattern).allMatches(text).cast<RegExpMatch>()) {
      final s = m.start;
      final e = m.end;
      final overlaps = matches.any((x) => s < x.end && e > x.start);
      if (overlaps) continue;
      matches.add(_MdMatch(s, e, kind, m));
    }
  }
  matches.sort((a, b) => a.start.compareTo(b.start));

  int cursor = 0;
  for (final m in matches) {
    if (m.start > cursor) {
      out.add(TextSpan(text: text.substring(cursor, m.start), style: base));
    }
    out.add(_renderMatch(m, base, caret));
    cursor = m.end;
  }
  if (cursor < text.length) {
    out.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return out;
}

TextSpan _renderMatch(_MdMatch mm, TextStyle base, int caret) {
  final caretInside = caret >= mm.start && caret <= mm.end;
  final marker = base.copyWith(
    color: caretInside ? AppColors.outline : Colors.transparent,
  );
  switch (mm.kind) {
    case _MdKind.bold:
      final inner = mm.match.group(1)!;
      return TextSpan(children: [
        TextSpan(text: '**', style: marker),
        TextSpan(text: inner, style: base.copyWith(fontWeight: FontWeight.w700)),
        TextSpan(text: '**', style: marker),
      ]);
    case _MdKind.italic:
      final inner = mm.match.group(1)!;
      return TextSpan(children: [
        TextSpan(text: '_', style: marker),
        TextSpan(text: inner, style: base.copyWith(fontStyle: FontStyle.italic)),
        TextSpan(text: '_', style: marker),
      ]);
    case _MdKind.code:
      final inner = mm.match.group(1)!;
      return TextSpan(children: [
        TextSpan(text: '`', style: marker),
        TextSpan(
          text: inner,
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: AppColors.surfaceContainerHigh,
          ),
        ),
        TextSpan(text: '`', style: marker),
      ]);
    case _MdKind.link:
      final label = mm.match.group(1)!;
      final url = mm.match.group(2)!;
      return TextSpan(children: [
        TextSpan(text: '[', style: marker),
        TextSpan(
          text: label,
          style: base.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        TextSpan(text: '](', style: marker),
        TextSpan(text: url, style: marker),
        TextSpan(text: ')', style: marker),
      ]);
    case _MdKind.url:
      return TextSpan(
        text: mm.match.group(0),
        style: base.copyWith(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
        ),
      );
  }
}
