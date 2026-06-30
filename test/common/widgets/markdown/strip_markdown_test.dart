import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/markdown/strip_markdown.dart';

import '../../../_helpers/fixtures.dart';

void main() {
  group('inline markers', () {
    test('strips bold `**x**` markers, keeps inner', () {
      expect(stripMarkdownPreview('this is **bold** text'),
          'this is bold text');
    });

    test('strips italic `*x*` markers', () {
      expect(stripMarkdownPreview('an *italic* word'), 'an italic word');
    });

    test('strips inline code `` `x` `` markers', () {
      expect(stripMarkdownPreview('hit `enter` to send'),
          'hit enter to send');
    });

    test('strips italic `_x_` at word boundary', () {
      expect(stripMarkdownPreview('an _italic_ word'), 'an italic word');
    });

    test('keeps snake_case (boundary rule)', () {
      expect(stripMarkdownPreview('the file is my_file_name.dart'),
          'the file is my_file_name.dart');
    });
  });

  group('links', () {
    test('rewrites [label](url) to the label', () {
      expect(stripMarkdownPreview('see [docs](https://example.com)'),
          'see docs');
    });

    test('handles multiple links', () {
      expect(stripMarkdownPreview('[a](u1) and [b](u2)'), 'a and b');
    });

    test('leaves a bare URL untouched', () {
      expect(stripMarkdownPreview('go to https://uniun.in/here'),
          'go to https://uniun.in/here');
    });

    test('leaves nostr: URI untouched', () {
      expect(
          stripMarkdownPreview('follow nostr:npub1abc'), 'follow nostr:npub1abc');
    });
  });

  group('line markers', () {
    test('strips ATX heading prefix', () {
      expect(stripMarkdownPreview('# Title'), 'Title');
      expect(stripMarkdownPreview('## Section'), 'Section');
      expect(stripMarkdownPreview('###### h6'), 'h6');
    });

    test('strips list bullet prefix', () {
      expect(stripMarkdownPreview('- item'), 'item');
      expect(stripMarkdownPreview('* item'), 'item');
    });

    test('strips numbered list prefix', () {
      expect(stripMarkdownPreview('1. first'), 'first');
      expect(stripMarkdownPreview('42. many'), 'many');
    });

    test('strips blockquote prefix', () {
      expect(stripMarkdownPreview('> quoted'), 'quoted');
    });

    test('multi-line markers all strip', () {
      const src = '# title\n- a\n- b\n> q';
      expect(stripMarkdownPreview(src), 'title\na\nb\nq');
    });

    test('strips with leading whitespace before marker', () {
      expect(stripMarkdownPreview('  - item'), 'item');
    });
  });

  group('passthroughs', () {
    test('plain text returns unchanged', () {
      expect(stripMarkdownPreview('hello world'), 'hello world');
    });

    test('empty string returns empty', () {
      expect(stripMarkdownPreview(''), '');
    });

    test('combined formatting strips all markers', () {
      expect(
          stripMarkdownPreview('# **Bold** and *italic* and `code`'),
          'Bold and italic and code');
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('unicode + emoji', () {
    test('plain emoji passes through', () {
      expect(stripMarkdownPreview(Content.emoji), Content.emoji);
    });

    test('multilingual content survives', () {
      expect(stripMarkdownPreview(Content.unicode), Content.unicode);
    });

    test('RTL text inside bold is unwrapped', () {
      expect(stripMarkdownPreview('**${Content.rtl}**'), Content.rtl);
    });

    test('emoji inside link label survives', () {
      expect(stripMarkdownPreview('[🐉 dragon](https://x)'), '🐉 dragon');
    });
  });

  group('malformed markdown', () {
    test('unbalanced bold strips the markers; content stays', () {
      expect(stripMarkdownPreview('**no end'), 'no end');
    });

    test('unbalanced italic underscore at word boundary strips', () {
      expect(stripMarkdownPreview('_no end'), 'no end');
    });

    test('lone backticks strip', () {
      expect(stripMarkdownPreview('partial `code'), 'partial code');
    });

    test('empty link label: regex requires 1+ chars, link left literal', () {
      expect(stripMarkdownPreview('see [](https://x.com)'),
          'see [](https://x.com)');
    });

    test('link without closing paren left as-is', () {
      expect(stripMarkdownPreview('[broken](https://x'), '[broken](https://x');
    });
  });

  group('nested formatting', () {
    test('bold inside italic strips both', () {
      expect(stripMarkdownPreview('_**bold**_'), 'bold');
    });

    test('inline marker inside line marker', () {
      expect(stripMarkdownPreview('# **bold heading**'), 'bold heading');
    });

    test('blockquote with italic + code', () {
      expect(stripMarkdownPreview('> _italic `code` here_'),
          'italic code here');
    });
  });

  group('whitespace', () {
    test('trailing newline preserved', () {
      expect(stripMarkdownPreview('hello\n'), 'hello\n');
    });

    test('multiple consecutive newlines preserved', () {
      expect(stripMarkdownPreview('a\n\n\nb'), 'a\n\n\nb');
    });

    test('all-whitespace input unchanged', () {
      expect(stripMarkdownPreview('   \t  \n  '), '   \t  \n  ');
    });
  });

  group('underscore boundaries', () {
    test('underscore mid-identifier not an italic boundary', () {
      expect(stripMarkdownPreview(Content.snakeCase), Content.snakeCase);
    });

    test('underscore after a space is stripped (open boundary)', () {
      // Boundary is "neighbour is not a word char". Leading space qualifies.
      expect(stripMarkdownPreview('use _private vars'), 'use private vars');
    });

    test('trailing underscore is stripped (close boundary at EOL)', () {
      expect(stripMarkdownPreview('trailing_'), 'trailing');
    });
  });

  group('lists', () {
    test('multi-digit numbered list strips', () {
      expect(stripMarkdownPreview('100. last'), 'last');
    });

    test('mixed-bullet list strips all', () {
      expect(stripMarkdownPreview('- a\n* b\n- c'), 'a\nb\nc');
    });

    test('empty blockquote strips marker', () {
      expect(stripMarkdownPreview('> '), '');
    });

    test('list inside blockquote — only outer marker per line', () {
      expect(stripMarkdownPreview('> - item'), '- item');
    });
  });

  group('scale', () {
    test('very long input is processed', () {
      final out = stripMarkdownPreview(Content.veryLong());
      expect(out, Content.veryLong());
    });

    test('all-markers input strips to plain words', () {
      const src =
          '# heading\n**bold** *italic* `code` _i2_ [a](u)\n> q\n- one\n1. two';
      expect(
        stripMarkdownPreview(src),
        'heading\nbold italic code i2 a\nq\none\ntwo',
      );
    });
  });
}
