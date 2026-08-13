import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/generation/prompt/composer_chat_prompt.dart';

PackedNote _note(String content) => PackedNote(
      id: 'n',
      content: content,
      created: DateTime(2026, 1, 1),
      source: PackedNoteSource.own,
    );

void main() {
  group('ComposerChatPromptTemplate.systemInstruction', () {
    test('mentions "the user\'s notes" when no Manas is picked', () {
      final s = ComposerChatPromptTemplate.systemInstruction();
      expect(s, contains("the user's notes"));
    });

    test('an empty manasName is treated the same as null', () {
      final s = ComposerChatPromptTemplate.systemInstruction(manasName: '');
      expect(s, contains("the user's notes"));
      expect(s, isNot(contains('""')));
    });

    test('names the picked Manas when provided', () {
      final s =
          ComposerChatPromptTemplate.systemInstruction(manasName: 'Work');
      expect(s, contains('the user\'s "Work" notes'));
    });

    test('has no trailing whitespace/newline', () {
      final s = ComposerChatPromptTemplate.systemInstruction();
      expect(s, isNot(endsWith('\n')));
      expect(s, isNot(endsWith(' ')));
    });
  });

  group('ComposerChatPromptTemplate.userMessage', () {
    test('omits the Conversation section when entityContext is empty', () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'what happened?',
        entityContext: const [],
        manasNotes: const [],
      );
      expect(msg, isNot(contains('## Conversation')));
    });

    test('includes conversation lines, collapsed, under the Conversation '
        'heading', () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const ['alice:   hi   there'],
        manasNotes: const [],
      );
      expect(msg, contains('## Conversation (most recent last)'));
      expect(msg, contains('- alice: hi there'));
    });

    test('a blank-after-collapse conversation line is skipped entirely', () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const ['   '],
        manasNotes: const [],
      );
      expect(msg, isNot(contains('- ')));
    });

    test('omits the Notes section when manasNotes is empty', () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const [],
        manasNotes: const [],
      );
      expect(msg, isNot(contains('## Notes')));
    });

    test('includes note content collapsed under the Notes heading', () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const [],
        manasNotes: [_note('multi\nline   note')],
      );
      expect(msg, contains('## Notes'));
      expect(msg, contains('- multi line note'));
    });

    test('a note that collapses to empty is skipped, not rendered as a '
        'blank bullet', () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const [],
        manasNotes: [_note('   \n  ')],
      );
      expect(msg, isNot(contains('- ')));
    });

    test('truncates a note longer than 300 chars with an ellipsis', () {
      final long = 'x' * 400;
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const [],
        manasNotes: [_note(long)],
      );
      expect(msg, contains('${'x' * 300}…'));
      expect(msg, isNot(contains('x' * 301)));
    });

    test('a note of exactly 300 chars is not truncated (boundary)', () {
      final exact = 'y' * 300;
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const [],
        manasNotes: [_note(exact)],
      );
      expect(msg, contains('- $exact'));
      expect(msg, isNot(contains('…')));
    });

    test('always ends with the Question section carrying the raw question',
        () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'what is the plan?',
        entityContext: const [],
        manasNotes: const [],
      );
      expect(msg, endsWith('## Question\nwhat is the plan?'));
    });

    test('renders Conversation, Notes and Question together in order',
        () {
      final msg = ComposerChatPromptTemplate.userMessage(
        question: 'q',
        entityContext: const ['bob: hey'],
        manasNotes: [_note('a note')],
      );
      final convoIdx = msg.indexOf('## Conversation');
      final notesIdx = msg.indexOf('## Notes');
      final questionIdx = msg.indexOf('## Question');
      expect(convoIdx, lessThan(notesIdx));
      expect(notesIdx, lessThan(questionIdx));
    });
  });
}
