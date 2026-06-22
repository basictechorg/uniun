// test/features/shiv/manthan/manthan_prompt_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/manthan/utils/manthan_prompt_builder.dart';

PackedNote _n(String content) => PackedNote(
      id: content.hashCode.toString(),
      content: content,
      created: DateTime(2026, 1, 1),
      source: PackedNoteSource.own,
    );

void main() {
  test('prompt starts with /no_think and lists every note', () {
    final out = ManthanPromptBuilder.build(
      notes: [_n('Amor fati'), _n('Antifragile systems')],
    );
    expect(out.trimLeft().startsWith('/no_think'), isTrue);
    expect(out, contains('Amor fati'));
    expect(out, contains('Antifragile systems'));
    expect(out, contains(ManthanPromptBuilder.noopSentinel));
  });

  test('collapses whitespace in note content', () {
    final out = ManthanPromptBuilder.build(notes: [_n('a\n\n  b')]);
    expect(out, contains('a b'));
    expect(out, isNot(contains('a\n\n  b')));
  });
}
