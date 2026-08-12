import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/repositories/group_message_repository.dart';
import 'package:uniun/domain/usecases/get_group_messages_usecase.dart';

import '../../_helpers/fixtures.dart';

class _MockGroupMessageRepository extends Mock
    implements GroupMessageRepository {}

void main() {
  late _MockGroupMessageRepository repo;

  setUp(() {
    repo = _MockGroupMessageRepository();
  });

  test('GetGroupMessagesUseCase forwards groupId/limit/before, defaults '
      'applied', () async {
    when(() => repo.getMessagesForGroup(groupId: 'g1', limit: 50, before: null))
        .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1')]));

    final result =
        await GetGroupMessagesUseCase(repo).call(const GetGroupMessagesInput(groupId: 'g1'));

    expect(result.getOrElse(() => []), hasLength(1));
    verify(() => repo.getMessagesForGroup(groupId: 'g1', limit: 50, before: null)).called(1);
  });

  test('GetGroupMessagesAfterUseCase forwards every field, defaults applied',
      () async {
    final after = DateTime(2026, 1, 1);
    when(() => repo.getMessagesForGroupAfter(
          groupId: 'g1',
          after: after,
          inclusive: false,
          limit: 10,
        )).thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1')]));

    await GetGroupMessagesAfterUseCase(repo)
        .call(GetGroupMessagesAfterInput(groupId: 'g1', after: after));

    verify(() => repo.getMessagesForGroupAfter(
          groupId: 'g1',
          after: after,
          inclusive: false,
          limit: 10,
        )).called(1);
  });

  test('GetGroupMessageByIdUseCase delegates to getMessageByEventId', () async {
    when(() => repo.getMessageByEventId('evt-1'))
        .thenAnswer((_) async => Right(aGroupMessage(groupId: 'g1')));

    await GetGroupMessageByIdUseCase(repo).call('evt-1');

    verify(() => repo.getMessageByEventId('evt-1')).called(1);
  });

  test('GetGroupMessageRepliesUseCase delegates to getGroupMessageReplies',
      () async {
    when(() => repo.getGroupMessageReplies('evt-1'))
        .thenAnswer((_) async => Right([aGroupMessage(groupId: 'g1')]));

    await GetGroupMessageRepliesUseCase(repo).call('evt-1');

    verify(() => repo.getGroupMessageReplies('evt-1')).called(1);
  });

  test('GetGroupMessageReplyCountUseCase delegates to '
      'getGroupMessageReplyCount', () async {
    when(() => repo.getGroupMessageReplyCount('evt-1'))
        .thenAnswer((_) async => const Right(3));

    final result = await GetGroupMessageReplyCountUseCase(repo).call('evt-1');

    expect(result, const Right<Failure, int>(3));
  });
}
