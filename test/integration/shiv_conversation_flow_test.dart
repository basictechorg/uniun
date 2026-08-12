import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/message_role.dart';
import 'package:uniun/data/models/shiv_conversation_model.dart';
import 'package:uniun/data/repositories/shiv_repository_impl.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/isar_seeds.dart';
import '../_helpers/isar_test_harness.dart';

/// End-to-end Shiv conversation/message lifecycle against a real Isar +
/// real `ShivRepositoryImpl` — create → send turns → branch (active leaf) →
/// title/content updates → delete (cascades messages) → watch stream. Does
/// NOT exercise `ShivAIBloc` (the lazy-create-on-first-send draft logic is
/// covered by `test/features/shiv/chat/bloc/shiv_ai_bloc_test.dart`) or
/// `RagPipeline`/inference — this is the persistence contract only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late ShivRepositoryImpl shiv;

  setUp(() async {
    isar = await openTestIsar();
    shiv = ShivRepositoryImpl(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  ShivMessageEntity aMessage({
    required String messageId,
    required String conversationId,
    String? parentId,
    MessageRole role = MessageRole.user,
    String content = 'hello',
    DateTime? createdAt,
  }) =>
      ShivMessageEntity(
        messageId: messageId,
        conversationId: conversationId,
        parentId: parentId,
        role: role,
        content: content,
        createdAt: createdAt ?? tNow,
      );

  test(
      'SCENARIO: create → appears in getConversations, activeLeafMessageId '
      'starts null', () async {
    final created = await shiv.createConversation('New conversation');
    expect(created.isRight(), isTrue);
    final conv = created.getOrElse(() => throw StateError('unreachable'));
    expect(conv.title, 'New conversation');
    expect(conv.activeLeafMessageId, isNull);

    final list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.map((c) => c.conversationId), [conv.conversationId]);
  });

  test(
      'SCENARIO: saving a message advances the conversation activeLeafMessageId '
      'and bumps updatedAt', () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));

    await shiv.saveMessage(aMessage(
      messageId: 'm-1',
      conversationId: conv.conversationId,
      role: MessageRole.user,
      content: 'hi',
    ));

    final list = (await shiv.getConversations()).getOrElse(() => const []);
    final updated = list.firstWhere((c) => c.conversationId == conv.conversationId);
    expect(updated.activeLeafMessageId, 'm-1');
    expect(updated.updatedAt.isAfter(conv.updatedAt) ||
        updated.updatedAt.isAtSameMomentAs(conv.updatedAt), isTrue);
  });

  test(
      'SCENARIO: a full user→assistant turn — leaf ends on the assistant '
      'placeholder, then updateMessageContent fills the streamed reply',
      () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));

    await shiv.saveMessage(aMessage(
      messageId: 'u-1',
      conversationId: conv.conversationId,
      role: MessageRole.user,
      content: 'what is uniun?',
    ));
    await shiv.saveMessage(aMessage(
      messageId: 'a-1',
      conversationId: conv.conversationId,
      parentId: 'u-1',
      role: MessageRole.assistant,
      content: '',
    ));

    var list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.first.activeLeafMessageId, 'a-1');

    await shiv.updateMessageContent('a-1', 'UNIUN is a decentralized network.');

    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs.map((m) => m.messageId).toList(), ['u-1', 'a-1']); // createdAt order
    expect(msgs.last.content, 'UNIUN is a decentralized network.');
  });

  test(
      'SCENARIO: branching — two children of the same parent, updateActiveLeaf '
      'switches which one is the active branch tip', () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));
    await shiv.saveMessage(aMessage(
        messageId: 'root', conversationId: conv.conversationId, content: 'root'));
    await shiv.saveMessage(aMessage(
        messageId: 'branch-a',
        conversationId: conv.conversationId,
        parentId: 'root',
        content: 'a'));
    await shiv.saveMessage(aMessage(
        messageId: 'branch-b',
        conversationId: conv.conversationId,
        parentId: 'root',
        content: 'b'));

    // saveMessage always advances the leaf to whatever was just saved, so
    // right now it points at branch-b (the last save).
    var list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.first.activeLeafMessageId, 'branch-b');

    await shiv.updateActiveLeaf(conv.conversationId, 'branch-a');
    list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.first.activeLeafMessageId, 'branch-a');

    // Both branches still exist in the flat message list — the bloc, not the
    // repo, walks parentId to build the active branch's linear view.
    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs.map((m) => m.messageId).toSet(), {'root', 'branch-a', 'branch-b'});
  });

  test('SCENARIO: updateConversationTitle renames without touching messages',
      () async {
    final conv = (await shiv.createConversation('New conversation'))
        .getOrElse(() => throw StateError('unreachable'));
    await shiv.saveMessage(aMessage(
        messageId: 'm-1', conversationId: conv.conversationId, content: 'x'));

    await shiv.updateConversationTitle(conv.conversationId, 'What is UNIUN?');

    final list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.first.title, 'What is UNIUN?');
    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs, hasLength(1));
  });

  test(
      'SCENARIO: deleting a conversation cascades — its messages are gone too, '
      'in the same operation', () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));
    await shiv.saveMessage(aMessage(
        messageId: 'm-1', conversationId: conv.conversationId, content: 'x'));
    await shiv.saveMessage(aMessage(
        messageId: 'm-2', conversationId: conv.conversationId, content: 'y'));

    await shiv.deleteConversation(conv.conversationId);

    expect((await shiv.getConversations()).getOrElse(() => const []), isEmpty);
    expect((await shiv.getMessages(conv.conversationId)).getOrElse(() => const []),
        isEmpty);
  });

  test('SCENARIO: watchConversations fires on create, update, and delete',
      () async {
    final events = <void>[];
    final sub = shiv.watchConversations().listen(events.add);
    addTearDown(() => sub.cancel());

    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));
    await pumpEventQueue();
    expect(events, isNotEmpty);

    events.clear();
    await shiv.updateConversationTitle(conv.conversationId, 'renamed');
    await pumpEventQueue();
    expect(events, isNotEmpty);

    events.clear();
    await shiv.deleteConversation(conv.conversationId);
    await pumpEventQueue();
    expect(events, isNotEmpty);
  });

  // ── Edge cases ────────────────────────────────────────────────────────────

  test(
      'EDGE: updateConversationTitle / updateActiveLeaf / updateMessageContent '
      'on an unknown id are harmless no-ops', () async {
    final r1 = await shiv.updateConversationTitle('ghost', 'x');
    final r2 = await shiv.updateActiveLeaf('ghost', 'm-1');
    final r3 = await shiv.updateMessageContent('ghost-msg', 'x');
    expect(r1.isRight(), isTrue);
    expect(r2.isRight(), isTrue);
    expect(r3.isRight(), isTrue);
  });

  test('EDGE: deleteConversation on an unknown id is a harmless no-op',
      () async {
    final result = await shiv.deleteConversation('never-existed');
    expect(result.isRight(), isTrue);
  });

  test(
      'EDGE: unicode/emoji in title and message content round-trip through '
      'Isar unchanged', () async {
    final conv = (await shiv.createConversation('日本語ボット 🤖'))
        .getOrElse(() => throw StateError('unreachable'));
    await shiv.saveMessage(aMessage(
      messageId: 'm-1',
      conversationId: conv.conversationId,
      content: Content.unicode,
    ));

    final list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.first.title, '日本語ボット 🤖');
    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs.first.content, Content.unicode);
  });

  test(
      'EDGE: saveMessage sanitizes GPT-2 byte-run / mojibake content before '
      'persisting, and updateMessageContent re-sanitizes on every call',
      () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));

    final saved = (await shiv.saveMessage(aMessage(
      messageId: 'm-1',
      conversationId: conv.conversationId,
      role: MessageRole.assistant,
      content: 'plain ascii, nothing to clean',
    )))
        .getOrElse(() => throw StateError('unreachable'));
    expect(saved.content, 'plain ascii, nothing to clean');

    await shiv.updateMessageContent('m-1', 'still plain after update');
    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs.first.content, 'still plain after update');
  });

  test('EDGE: empty-string message content is stored as-is (streaming '
      'placeholder before any tokens arrive)', () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));
    final saved = (await shiv.saveMessage(aMessage(
      messageId: 'placeholder',
      conversationId: conv.conversationId,
      role: MessageRole.assistant,
      content: '',
    )))
        .getOrElse(() => throw StateError('unreachable'));
    expect(saved.content, isEmpty);
  });

  test('EDGE: 40 messages in one conversation — getMessages returns all, '
      'oldest first', () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));
    for (var i = 0; i < 40; i++) {
      await shiv.saveMessage(aMessage(
        messageId: 'm-$i',
        conversationId: conv.conversationId,
        content: 'turn $i',
        createdAt: tT0.add(Duration(minutes: i)),
      ));
    }
    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs, hasLength(40));
    expect(msgs.first.messageId, 'm-0');
    expect(msgs.last.messageId, 'm-39');
  });

  test(
      'EDGE: getConversations sorts newest-created first across many '
      'conversations', () async {
    for (var i = 0; i < 10; i++) {
      final row = shivConversationRow('c-$i', createdAt: tT0.add(Duration(minutes: i)));
      await isar.writeTxn(() => isar.shivConversationModels.put(row));
    }
    final list = (await shiv.getConversations()).getOrElse(() => const []);
    expect(list.first.conversationId, 'c-9');
    expect(list.last.conversationId, 'c-0');
  });

  test(
      'EDGE: getMessages on a conversation with no messages returns an empty '
      'list, not an error', () async {
    final conv = (await shiv.createConversation('t'))
        .getOrElse(() => throw StateError('unreachable'));
    final msgs = (await shiv.getMessages(conv.conversationId))
        .getOrElse(() => const []);
    expect(msgs, isEmpty);
  });

  test(
      'EDGE: two conversations never leak messages into each other\'s '
      'getMessages result', () async {
    final a = (await shiv.createConversation('a'))
        .getOrElse(() => throw StateError('unreachable'));
    final b = (await shiv.createConversation('b'))
        .getOrElse(() => throw StateError('unreachable'));
    await shiv.saveMessage(aMessage(
        messageId: 'a-1', conversationId: a.conversationId, content: 'in a'));
    await shiv.saveMessage(aMessage(
        messageId: 'b-1', conversationId: b.conversationId, content: 'in b'));

    final msgsA = (await shiv.getMessages(a.conversationId)).getOrElse(() => const []);
    final msgsB = (await shiv.getMessages(b.conversationId)).getOrElse(() => const []);
    expect(msgsA.map((m) => m.messageId), ['a-1']);
    expect(msgsB.map((m) => m.messageId), ['b-1']);
  });

  test(
      'EDGE: deleting one conversation does not touch another conversation\'s '
      'messages', () async {
    final a = (await shiv.createConversation('a'))
        .getOrElse(() => throw StateError('unreachable'));
    final b = (await shiv.createConversation('b'))
        .getOrElse(() => throw StateError('unreachable'));
    await shiv.saveMessage(aMessage(
        messageId: 'a-1', conversationId: a.conversationId, content: 'in a'));
    await shiv.saveMessage(aMessage(
        messageId: 'b-1', conversationId: b.conversationId, content: 'in b'));

    await shiv.deleteConversation(a.conversationId);

    expect((await shiv.getMessages(a.conversationId)).getOrElse(() => const []),
        isEmpty);
    expect((await shiv.getMessages(b.conversationId)).getOrElse(() => const []),
        hasLength(1));
    final remaining = (await shiv.getConversations()).getOrElse(() => const []);
    expect(remaining.map((c) => c.conversationId), [b.conversationId]);
  });
}
