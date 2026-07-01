import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:uniun/common/widgets/markdown/markdown_link_handler.dart';
import 'package:uniun/core/theme/app_custom_colors.dart';
/// Renders note text as markdown using a deliberately tight subset:
/// headings (H1–H3) / bold / italic / inline code / bullet + numbered lists /
/// blockquotes / links.
///
/// Disabled by intent: images (uses `imeta` tag instead), tables, fenced code
/// blocks. Bare URLs and `nostr:` URIs are auto-linked via the custom inline
/// syntaxes below; bare HTTP URLs are also shortened to host-only display by
/// [_shortenBareUrls] before parsing.
class NoteMarkdownBody extends StatelessWidget {
  const NoteMarkdownBody({
    super.key,
    required this.content,
    this.style,
    this.linkColor,
    this.onTap,
  });

  final String content;

  /// Base text style. Other markdown styles are derived from it.
  final TextStyle? style;

  /// Link colour override. Defaults to [Theme.of(context).colorScheme.primary].
  final Color? linkColor;

  /// Tap handler for the body text. The body is always selectable
  /// (`SelectableText.rich`), whose own recognizer wins the gesture arena and
  /// swallows an ancestor card's `InkWell.onTap`. Wiring this into
  /// `SelectableText.onTap` keeps a simple tap working (e.g. open the thread)
  /// while long-press still selects text. Leave null where the card doesn't
  /// navigate.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        TextStyle(
          fontSize: 15,
          color: context.custom.textBody,
          height: 1.55,
        );
    final link = linkColor ?? Theme.of(context).colorScheme.primary;

    return MarkdownBody(
      data: _shortenBareUrls(content),
      selectable: true,
      onTapText: onTap,
      softLineBreak: false,
      extensionSet: _extensions,
      onTapLink: (text, href, title) {
        if (href != null) handleMarkdownLink(context, href);
      },
      styleSheet: _buildStyleSheet(context, base, link),
    );
  }
}

/// Defaults from the markdown parser already cover paragraphs, lists,
/// blockquotes, inline code, emphasis. We only extend with autolink for
/// bare URLs and a custom inline syntax for `nostr:` URIs.
final md.ExtensionSet _extensions = md.ExtensionSet(
  const <md.BlockSyntax>[],
  <md.InlineSyntax>[
    md.AutolinkExtensionSyntax(),
    _NostrUriSyntax(),
  ],
);

/// Rewrites bare `http(s)://…` URLs in [content] as markdown links
/// `[host](full-url)` so the renderer displays just the host while keeping
/// the full URL as the tap target. Skips URLs already inside `[label](url)`
/// brackets to avoid double-rewriting.
String _shortenBareUrls(String content) {
  // Negative-lookbehind for `](` would be ideal but Dart's RegExp lookbehind
  // is limited; cheap structural check: skip matches where the char two
  // positions before the match start is `]` and one position before is `(`.
  return content.replaceAllMapped(
    RegExp(r'https?://[^\s)<>]+'),
    (m) {
      final start = m.start;
      if (start >= 2 &&
          content[start - 1] == '(' &&
          content[start - 2] == ']') {
        return m.group(0)!;
      }
      final url = m.group(0)!;
      final hostMatch = RegExp(r'^https?://(?:www\.)?([^/]+)').firstMatch(url);
      final host = hostMatch?.group(1) ?? url;
      return '[$host]($url)';
    },
  );
}

/// Matches bare `nostr:npub1…` URIs and converts them to markdown links so
/// the standard `onTapLink` flow opens the in-app user profile. Other Nostr
/// URI prefixes (`note1`, `nevent1`, `nprofile1`) stay as plain text until
/// we have UI to author them.
class _NostrUriSyntax extends md.InlineSyntax {
  _NostrUriSyntax() : super(r'nostr:npub1[a-z0-9]+');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final uri = match[0]!;
    final anchor = md.Element.text('a', uri);
    anchor.attributes['href'] = uri;
    parser.addNode(anchor);
    return true;
  }
}

MarkdownStyleSheet _buildStyleSheet(
    BuildContext context, TextStyle base, Color link) {
  final colorScheme = Theme.of(context).colorScheme;
  final code = base.copyWith(
    fontFamily: 'monospace',
    fontSize: (base.fontSize ?? 15) - 1,
    backgroundColor: colorScheme.surfaceContainerHigh,
  );
  final baseSize = base.fontSize ?? 15;
  return MarkdownStyleSheet(
    p: base,
    a: base.copyWith(color: link, decoration: TextDecoration.underline),
    strong: base.copyWith(fontWeight: FontWeight.w700),
    em: base.copyWith(fontStyle: FontStyle.italic),
    h1: base.copyWith(fontSize: baseSize + 9, fontWeight: FontWeight.w800, height: 1.3),
    h2: base.copyWith(fontSize: baseSize + 6, fontWeight: FontWeight.w800, height: 1.3),
    h3: base.copyWith(fontSize: baseSize + 3, fontWeight: FontWeight.w700, height: 1.3),
    h1Padding: const EdgeInsets.only(top: 4, bottom: 2),
    h2Padding: const EdgeInsets.only(top: 4, bottom: 2),
    h3Padding: const EdgeInsets.only(top: 2, bottom: 2),
    code: code,
    codeblockDecoration: BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
    ),
    blockquote: base.copyWith(color: colorScheme.onSurfaceVariant),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.4), width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
    listBullet: base,
    listIndent: 18,
    pPadding: EdgeInsets.zero,
    blockSpacing: 6,
  );
}
