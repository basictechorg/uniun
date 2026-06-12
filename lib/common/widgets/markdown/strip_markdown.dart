/// Strips the subset of markdown we render in [NoteMarkdownBody] from [text],
/// for plain-text previews where rendering markdown isn't possible (tight
/// row previews, single-line summaries).
///
/// Handles: bold (`**x**`), italic (`*x*` / `_x_`), inline code (`` `x` ``),
/// links (`[text](url)` → `text`), bullet/numbered list markers, blockquote
/// markers. Leaves bare URLs and `nostr:` URIs alone — they're already short
/// and readable.
String stripMarkdownPreview(String text) {
  var out = text;
  // [label](href) → label
  out = out.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    (m) => m.group(1) ?? '',
  );
  // Leading line markers: heading `# / ## / ###`, list `- ` / `* ` / `1. `,
  // blockquote `> `. Multi-line, anchored to line start.
  out = out.replaceAll(
    RegExp(r'^[ \t]*(?:#{1,6}\s+|[-*]\s+|\d+\.\s+|>\s*)', multiLine: true),
    '',
  );
  // **bold**, *italic*, `code`
  out = out.replaceAll(RegExp(r'\*\*|\*|`'), '');
  // _italic_ — only when at a word boundary so `snake_case` survives.
  out = out.replaceAll(RegExp(r'(?<!\w)_|_(?!\w)'), '');
  return out;
}
