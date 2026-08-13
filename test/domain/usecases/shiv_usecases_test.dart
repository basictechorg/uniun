import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/message_role.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/shiv/shiv_conversation_entity.dart';
import 'package:uniun/domain/entities/shiv/shiv_message_entity.dart';
import 'package:uniun/domain/repositories/shiv_repository.dart';
import 'package:uniun/domain/usecases/shiv_usecases.dart';

class _MockShivRepository extends Mock implements ShivRepository {}

ShivConversationEntity _aConversation() => ShivConversationEntity(
      conversationId: 'conv-1',
      title: 'Test',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

ShivMessageEntity _aMessage() => ShivMessageEntity(
      messageId: 'msg-1',
      conversationId: 'conv-1',
      role: MessageRole.user,
      content: 'hi',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockShivRepository repo;

  setUp(() {
    repo = _MockShivRepository();
  });

  test('GetConversationsUseCase delegates to getConversations', () async {
    when(() => repo.getConversations()).thenAnswer((_) async => Right([_aConversation()]));

    final result = await GetConversationsUseCase(repo).call();

    expect(result.getOrElse(() => []), hasLength(1));
  });

  test('WatchConversationsUseCase forwards to watchConversations', () {
    when(() => repo.watchConversations()).thenAnswer((_) => const Stream.empty());

    final stream = WatchConversationsUseCase(repo).call();

    expect(stream, isA<Stream<void>>());
    verify(() => repo.watchConversations()).called(1);
  });

  test('CreateConversationUseCase delegates to createConversation', () async {
    when(() => repo.createConversation('title')).thenAnswer((_) async => Right(_aConversation()));

    await CreateConversationUseCase(repo).call('title');

    verify(() => repo.createConversation('title')).called(1);
  });

  test('DeleteConversationUseCase delegates to deleteConversation', () async {
    when(() => repo.deleteConversation('conv-1')).thenAnswer((_) async => const Right(unit));

    final result = await DeleteConversationUseCase(repo).call('conv-1');

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('GetMessagesUseCase delegates to getMessages', () async {
    when(() => repo.getMessages('conv-1')).thenAnswer((_) async => Right([_aMessage()]));

    await GetMessagesUseCase(repo).call('conv-1');

    verify(() => repo.getMessages('conv-1')).called(1);
  });

  test('SaveMessageUseCase delegates to saveMessage', () async {
    final msg = _aMessage();
    when(() => repo.saveMessage(msg)).thenAnswer((_) async => Right(msg));

    final result = await SaveMessageUseCase(repo).call(msg);

    expect(result, Right(msg));
  });

  test('UpdateMessageContentUseCase forwards both fields', () async {
    when(() => repo.updateMessageContent('msg-1', 'new content'))
        .thenAnswer((_) async => const Right(unit));

    await UpdateMessageContentUseCase(repo).call(('msg-1', 'new content'));

    verify(() => repo.updateMessageContent('msg-1', 'new content')).called(1);
  });

  test('UpdateConversationTitleUseCase forwards both fields', () async {
    when(() => repo.updateConversationTitle('conv-1', 'new title'))
        .thenAnswer((_) async => const Right(unit));

    await UpdateConversationTitleUseCase(repo).call(('conv-1', 'new title'));

    verify(() => repo.updateConversationTitle('conv-1', 'new title')).called(1);
  });

  test('UpdateActiveLeafUseCase forwards both fields', () async {
    when(() => repo.updateActiveLeaf('conv-1', 'msg-2'))
        .thenAnswer((_) async => const Right(unit));

    await UpdateActiveLeafUseCase(repo).call(('conv-1', 'msg-2'));

    verify(() => repo.updateActiveLeaf('conv-1', 'msg-2')).called(1);
  });
}
