import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/enum/message_role.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';
import 'package:uniun/features/shiv/generation/chat_helpers.dart';

import '../../../_helpers/fixtures.dart';

/// Covers: stripThinking, buildBranch, entityContextLines, pairCleanHistory —
/// the pure chat-text helpers shared by ShivAIBloc and composer-chat.
void main() {
  ShivMessageEntity aMsg({
    required String messageId,
    String? parentId,
    MessageRole role = MessageRole.user,
    String content = 'x',
    DateTime? createdAt,
  }) =>
      ShivMessageEntity(
        messageId: messageId,
        conversationId: 'c-1',
        parentId: parentId,
        role: role,
        content: content,
        createdAt: createdAt ?? tNow,
      );

  group('stripThinking', () {
    test('removes a single think block', () {
      expect(stripThinking('<think>reasoning</think>answer'), 'answer');
    });

    test('removes multiple think blocks', () {
      expect(stripThinking('<think>a</think>mid<think>b</think>end'), 'midend');
    });

    test('is case-insensitive on the tag', () {
      expect(stripThinking('<THINK>x</THINK>answer'), 'answer');
    });

    test('trims surrounding whitespace after stripping', () {
      expect(stripThinking('  <think>x</think>  answer  '), 'answer');
    });

    test('leaves content unchanged when there is no think block', () {
      expect(stripThinking('plain answer'), 'plain answer');
    });

    test('an unclosed think tag consumes everything after it (regex is '
        'non-greedy but requires a closing tag to match at all)', () {
      expect(stripThinking('<think>never closes'), '<think>never closes');
    });

    // ── Edge cases ──────────────────────────────────────────────────────

    test('empty string stays empty', () {
      expect(stripThinking(''), '');
    });

    test('whitespace-only content trims to empty', () {
      expect(stripThinking('   \n\t  '), '');
    });

    test('think block spanning newlines is fully removed ([\\s\\S] matches '
        'newlines, unlike a plain "." would)', () {
      expect(stripThinking('<think>line1\nline2\nline3</think>answer'), 'answer');
    });

    test('unicode/emoji content survives stripping untouched', () {
      expect(stripThinking('<think>推理</think>${Content.unicode}'),
          Content.unicode);
    });

    test('content that is ONLY a think block strips to empty', () {
      expect(stripThinking('<think>only reasoning</think>'), '');
    });
  });

  group('buildBranch', () {
    test('walks a linear chain from leaf to root, returns root-first', () {
      final all = [
        aMsg(messageId: 'root', content: 'r'),
        aMsg(messageId: 'mid', parentId: 'root', content: 'm'),
        aMsg(messageId: 'leaf', parentId: 'mid', content: 'l'),
      ];
      final branch = buildBranch('leaf', all);
      expect(branch.map((m) => m.messageId).toList(), ['root', 'mid', 'leaf']);
    });

    test('a single-node branch (leaf with no parent) returns just that node',
        () {
      final all = [aMsg(messageId: 'only', content: 'x')];
      final branch = buildBranch('only', all);
      expect(branch.map((m) => m.messageId).toList(), ['only']);
    });

    test('an unknown leafId returns an empty list', () {
      final all = [aMsg(messageId: 'a', content: 'x')];
      expect(buildBranch('ghost', all), isEmpty);
    });

    test('a broken chain (parentId points at a message not in `all`) stops '
        'at the missing link instead of throwing', () {
      final all = [
        aMsg(messageId: 'leaf', parentId: 'missing-parent', content: 'l'),
      ];
      final branch = buildBranch('leaf', all);
      expect(branch.map((m) => m.messageId).toList(), ['leaf']);
    });

    test('picks the correct branch when the tree forks — sibling branches '
        'are excluded', () {
      final all = [
        aMsg(messageId: 'root', content: 'r'),
        aMsg(messageId: 'branch-a', parentId: 'root', content: 'a'),
        aMsg(messageId: 'branch-b', parentId: 'root', content: 'b'),
      ];
      expect(buildBranch('branch-a', all).map((m) => m.messageId),
          ['root', 'branch-a']);
      expect(buildBranch('branch-b', all).map((m) => m.messageId),
          ['root', 'branch-b']);
    });

    test('empty `all` list returns an empty branch regardless of leafId', () {
      expect(buildBranch('anything', const []), isEmpty);
    });
  });

  group('entityContextLines', () {
    test('formats each note as "@shortpubkey: content"', () {
      final lines = entityContextLines([aNote(authorPubkey: kAlicePub, content: 'hi')]);
      expect(lines, ['@alice-pu: hi']);
    });

    test('a pubkey <= 8 chars is NOT truncated, just prefixed with @', () {
      final lines = entityContextLines([aNote(authorPubkey: 'short', content: 'x')]);
      expect(lines, ['@short: x']);
    });

    test('keeps only the last [max] notes, oldest of those first', () {
      final notes = [for (var i = 0; i < 5; i++) aNote(id: 'n$i', content: 'msg$i')];
      final lines = entityContextLines(notes, max: 2);
      expect(lines, ['@alice-pu: msg3', '@alice-pu: msg4']);
    });

    test('content longer than maxChars is truncated with an ellipsis', () {
      final note = aNote(content: 'a' * 300);
      final lines = entityContextLines([note], maxChars: 10);
      expect(lines.single, '@alice-pu: ${'a' * 10}…');
    });

    test('content exactly at maxChars is not truncated', () {
      final note = aNote(content: 'a' * 10);
      final lines = entityContextLines([note], maxChars: 10);
      expect(lines.single, '@alice-pu: ${'a' * 10}');
    });

    test('an empty notes list returns an empty list', () {
      expect(entityContextLines(const []), isEmpty);
    });

    test('fewer notes than [max] returns all of them, unaltered order', () {
      final notes = [aNote(id: 'n0', content: 'a'), aNote(id: 'n1', content: 'b')];
      final lines = entityContextLines(notes, max: 10);
      expect(lines, ['@alice-pu: a', '@alice-pu: b']);
    });

    test('unicode/emoji content is preserved verbatim (no truncation at the '
        'default 240-char cap)', () {
      final note = aNote(content: Content.unicode);
      final lines = entityContextLines([note]);
      expect(lines.single, '@alice-pu: ${Content.unicode}');
    });
  });

  group('pairCleanHistory', () {
    test('pairs a user turn with the following assistant turn', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: 'q1'),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'r1'),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 3), [('q1', 'r1')]);
    });

    test('an orphan trailing user turn (no reply yet) is dropped', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: 'q1'),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'r1'),
        aMsg(messageId: 'u2', role: MessageRole.user, content: 'q2 pending'),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 3), [('q1', 'r1')]);
    });

    test('empty placeholder assistant messages (mid-stream) are skipped, not '
        'paired as empty replies', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: 'q1'),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: ''),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 3), isEmpty);
    });

    test('an orphan assistant message with no preceding user turn is '
        'skipped entirely', () {
      final msgs = [
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'unsolicited'),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 3), isEmpty);
    });

    test('caps to the most recent maxPairs pairs, dropping the oldest', () {
      final msgs = <ShivMessageEntity>[];
      for (var i = 0; i < 5; i++) {
        msgs.add(aMsg(messageId: 'u$i', role: MessageRole.user, content: 'q$i'));
        msgs.add(aMsg(messageId: 'a$i', role: MessageRole.assistant, content: 'r$i'));
      }
      final pairs = pairCleanHistory(msgs, maxPairs: 2);
      expect(pairs, [('q3', 'r3'), ('q4', 'r4')]);
    });

    test('maxPairs of 0 returns no pairs at all', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: 'q1'),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'r1'),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 0), isEmpty);
    });

    test('exactly maxPairs pairs returns all of them, order preserved', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: 'q1'),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'r1'),
        aMsg(messageId: 'u2', role: MessageRole.user, content: 'q2'),
        aMsg(messageId: 'a2', role: MessageRole.assistant, content: 'r2'),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 2), [('q1', 'r1'), ('q2', 'r2')]);
    });

    test('empty message list returns no pairs', () {
      expect(pairCleanHistory(const [], maxPairs: 3), isEmpty);
    });

    test('whitespace-only content on either side of a turn is treated as '
        'empty and skipped', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: '   '),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'r1'),
      ];
      // The whitespace-only user turn never sets pendingUser, so the
      // following assistant reply has nothing to pair with and is dropped.
      expect(pairCleanHistory(msgs, maxPairs: 3), isEmpty);
    });

    test('a second consecutive user turn overwrites the pending one — only '
        'the latest unanswered question survives to pair', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: 'q1 (edited away)'),
        aMsg(messageId: 'u2', role: MessageRole.user, content: 'q2 (final)'),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: 'r1'),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 3), [('q2 (final)', 'r1')]);
    });

    test('unicode/emoji content round-trips through a pair unchanged', () {
      final msgs = [
        aMsg(messageId: 'u1', role: MessageRole.user, content: Content.unicode),
        aMsg(messageId: 'a1', role: MessageRole.assistant, content: Content.emoji),
      ];
      expect(pairCleanHistory(msgs, maxPairs: 3), [(Content.unicode, Content.emoji)]);
    });
  });
}
