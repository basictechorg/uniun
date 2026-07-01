import 'package:flutter/material.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Horizontal row of inline-formatting buttons that operate on a shared
/// [TextEditingController]. Wraps the current selection, or inserts a stub
/// at the cursor and places the caret inside.
class MarkdownFormattingToolbar extends StatelessWidget {
  const MarkdownFormattingToolbar({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          _Btn(icon: Icons.title_rounded, tooltip: l10n.markdownToolbarHeading,
              onTap: () => _cycleHeading(controller)),
          _Btn(icon: Icons.format_bold_rounded, tooltip: l10n.markdownToolbarBold,
              onTap: () => _wrap(controller, '**', '**')),
          _Btn(icon: Icons.format_italic_rounded, tooltip: l10n.markdownToolbarItalic,
              onTap: () => _wrap(controller, '_', '_')),
          _Btn(icon: Icons.code_rounded, tooltip: l10n.markdownToolbarCode,
              onTap: () => _wrap(controller, '`', '`')),
          _Btn(icon: Icons.format_list_bulleted_rounded, tooltip: l10n.markdownToolbarBulletList,
              onTap: () => _prefixLines(controller, '- ')),
          _Btn(icon: Icons.format_list_numbered_rounded, tooltip: l10n.markdownToolbarNumberList,
              onTap: () => _prefixLines(controller, '1. ')),
          _Btn(icon: Icons.format_quote_rounded, tooltip: l10n.markdownToolbarQuote,
              onTap: () => _prefixLines(controller, '> ')),
          _Btn(icon: Icons.link_rounded, tooltip: l10n.markdownToolbarLink,
              onTap: () => _insertLink(controller)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

void _wrap(TextEditingController c, String before, String after) {
  final sel = c.selection;
  final text = c.text;
  if (!sel.isValid) {
    _setText(c, text + before + after, text.length + before.length);
    return;
  }
  final selected = sel.textInside(text);
  final newText = sel.textBefore(text) + before + selected + after + sel.textAfter(text);
  final caret = selected.isEmpty
      ? sel.start + before.length
      : sel.start + before.length + selected.length + after.length;
  _setText(c, newText, caret);
}

void _prefixLines(TextEditingController c, String prefix) {
  final sel = c.selection;
  final text = c.text;
  if (!sel.isValid) {
    final needsNewline = text.isNotEmpty && !text.endsWith('\n');
    final insertion = (needsNewline ? '\n' : '') + prefix;
    _setText(c, text + insertion, text.length + insertion.length);
    return;
  }
  final start = _lineStart(text, sel.start);
  final region = text.substring(start, sel.end);
  final prefixed = region
      .split('\n')
      .map((l) => '$prefix$l')
      .join('\n');
  final newText = text.substring(0, start) + prefixed + text.substring(sel.end);
  _setText(c, newText, start + prefixed.length);
}

void _insertLink(TextEditingController c) {
  final sel = c.selection;
  final text = c.text;
  if (!sel.isValid || sel.isCollapsed) {
    const stub = '[text](https://)';
    const placeholder = 'text';
    final at = sel.isValid ? sel.start : text.length;
    final newText = text.substring(0, at) + stub + text.substring(at);
    // Select the "text" placeholder so the next keystroke replaces it.
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: at + 1,
        extentOffset: at + 1 + placeholder.length,
      ),
    );
    return;
  }
  final label = sel.textInside(text);
  final replacement = '[$label](https://)';
  final newText = sel.textBefore(text) + replacement + sel.textAfter(text);
  // Caret lands just inside the closing paren so the user types the URL.
  _setText(c, newText, sel.start + replacement.length - 1);
}

int _lineStart(String text, int index) {
  if (index <= 0) return 0;
  final nl = text.lastIndexOf('\n', index - 1);
  return nl < 0 ? 0 : nl + 1;
}

/// Toggles the current line's heading marker through: none → `# ` → `## `
/// → `### ` → none. Lets one button cover H1/H2/H3 — same affordance Obsidian
/// uses (cycle by repeated taps).
void _cycleHeading(TextEditingController c) {
  final sel = c.selection;
  final text = c.text;
  final at = sel.isValid ? sel.start : text.length;
  final start = _lineStart(text, at);
  final nl = text.indexOf('\n', start);
  final lineEnd = nl < 0 ? text.length : nl;
  final line = text.substring(start, lineEnd);

  final match = RegExp(r'^(#{1,3}) ').firstMatch(line);
  String newLine;
  int caretShift;
  if (match == null) {
    newLine = '# $line';
    caretShift = 2;
  } else {
    final level = match.group(1)!.length;
    if (level < 3) {
      newLine = '#$line';
      caretShift = 1;
    } else {
      newLine = line.substring(4);
      caretShift = -4;
    }
  }

  final newText = text.substring(0, start) + newLine + text.substring(lineEnd);
  _setText(c, newText, at + caretShift);
}

void _setText(TextEditingController c, String text, int caret) {
  c.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
  );
}
