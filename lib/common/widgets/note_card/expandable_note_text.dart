import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Renders a note's text body, collapsing to [collapsedMaxLines] lines with a
/// "Read more" toggle when the content is longer. The toggle only appears when
/// the text actually overflows the collapsed limit (measured with a
/// [TextPainter]), so short notes render unchanged.
///
/// Used by the feed [NoteCard] and both DM bubbles. The focused [LargeNoteCard]
/// deliberately does NOT use this — it always shows the full note.
class ExpandableNoteText extends StatefulWidget {
  const ExpandableNoteText({
    super.key,
    required this.text,
    required this.style,
    this.collapsedMaxLines = 4,
    this.actionColor,
  });

  final String text;
  final TextStyle style;
  final int collapsedMaxLines;

  /// Colour of the "Read more"/"Read less" action. Defaults to the primary
  /// colour; pass an on-bubble colour when rendered on a coloured background.
  final Color? actionColor;

  @override
  State<ExpandableNoteText> createState() => _ExpandableNoteTextState();
}

class _ExpandableNoteTextState extends State<ExpandableNoteText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actionColor = widget.actionColor ?? AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.collapsedMaxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.collapsedMaxLines,
              overflow:
                  _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
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
      },
    );
  }
}
