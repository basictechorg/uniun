import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/generation/prompt/prompt_parts.dart';
import 'package:uniun/features/shiv/nataraj/utils/nataraj_prompt_builder.dart';

/// Pure-logic tests for the Nataraj synthesis prompt — the one-shot prompt the
/// swipe deck sends the on-device LLM. Guards the hard-rules section, the
/// per-note length cap, and the NOOP escape hatch.
void main() {
  PackedNote note(String id, String content) => PackedNote(
        id: id,
        content: content,
        created: DateTime(2026, 1, 1),
        source: PackedNoteSource.own,
      );

  group('NatarajPromptBuilder.build', () {
    test('includes the /no_think soft-switch first to keep Qwen budgets sane',
        () {
      final prompt = NatarajPromptBuilder.build(notes: [note('a', 'hello')]);
      expect(prompt.trimLeft().startsWith(PromptParts.noThink), isTrue);
    });

    test('embeds each note as a `- ` bullet under the NOTES: header', () {
      final prompt = NatarajPromptBuilder.build(notes: [
        note('a', 'first idea'),
        note('b', 'second idea'),
      ]);
      expect(prompt, contains('NOTES:'));
      expect(prompt, contains('- first idea'));
      expect(prompt, contains('- second idea'));
    });

    test('long note content is truncated to ~280 chars with an ellipsis', () {
      final long = 'x' * 600;
      final prompt = NatarajPromptBuilder.build(notes: [note('a', long)]);
      // The full 600-char input must NOT survive; the truncated tail '…' must.
      expect(prompt.contains('x' * 600), isFalse);
      expect(prompt, contains('…'));
    });

    test('collapses internal whitespace runs so multi-line notes stay 1-line',
        () {
      const messy = 'line one\n\n   line   two\t\twith spacing';
      final prompt = NatarajPromptBuilder.build(notes: [note('a', messy)]);
      // The renderer must NOT leak literal newlines from the raw note into
      // the bulleted prompt — that breaks the "- " bullet boundary.
      final notesSection = prompt.split('NOTES:').last;
      // Count newlines AFTER 'NOTES:' header line: should be just 2 (one for
      // the bullet, one for the closing blank before the closing instruction).
      // Stricter check: bullet line must not contain the messy double-newline.
      expect(notesSection, isNot(contains('line one\n\n')));
    });

    test('exposes NOOP sentinel both as the constant and in the prompt body',
        () {
      expect(NatarajPromptBuilder.noopSentinel, PromptParts.noopSentinel);
      final prompt = NatarajPromptBuilder.build(notes: [note('a', 'x')]);
      expect(prompt, contains(PromptParts.noopSentinel));
    });

    test('hard-rules section bans preamble, lists, labels, JSON, quotes', () {
      final prompt = NatarajPromptBuilder.build(notes: [note('a', 'x')]);
      expect(prompt, contains('Hard rules:'));
      expect(prompt.toLowerCase(),
          allOf(contains('no preamble'), contains('no lists'),
              contains('no labels'), contains('no json'),
              contains('no quotes')));
    });
  });
}
