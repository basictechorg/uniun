import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/markdown/note_markdown_body.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Renders a note body as markdown and collapses to a character-count preview
/// with a "Read more" toggle when the source text is longer than
/// [collapsedMaxChars]. Pure source-length truncation keeps the collapsed
/// state cheap (no TextPainter measurement) and predictable across the markdown
/// subset (bold/italic/code/lists/links).
class ExpandableNoteText extends StatefulWidget {
  const ExpandableNoteText({
    super.key,
    required this.text,
    required this.style,
    this.collapsedMaxChars = 280,
    this.actionColor,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final int collapsedMaxChars;

  /// Colour of the "Read more"/"Read less" action. Defaults to primary; pass
  /// an on-bubble colour when rendered on a coloured background.
  final Color? actionColor;

  /// Forwarded to [NoteMarkdownBody.onTap]. Pass the card's tap handler inside
  /// a tappable card so a simple tap on the (selectable) body still triggers it
  /// — long-press keeps selecting text.
  final VoidCallback? onTap;

  @override
  State<ExpandableNoteText> createState() => _ExpandableNoteTextState();
}

class _ExpandableNoteTextState extends State<ExpandableNoteText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actionColor =
        widget.actionColor ?? Theme.of(context).colorScheme.primary;

    final overflows = widget.text.length > widget.collapsedMaxChars;
    final shown = (overflows && !_expanded)
        ? '${widget.text.substring(0, widget.collapsedMaxChars).trimRight()}…'
        : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteMarkdownBody(
          content: shown,
          style: widget.style,
          linkColor: actionColor,
          onTap: widget.onTap,
        ),
        if (overflows)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? l10n.actionReadLess : l10n.actionReadMore,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: actionColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
