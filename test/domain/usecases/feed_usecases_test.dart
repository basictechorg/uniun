import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/repositories/feed_repository.dart';
import 'package:uniun/domain/usecases/feed_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockFeedRepository extends Mock implements FeedRepository {}

void main() {
  late _MockFeedRepository repo;

  setUp(() {
    repo = _MockFeedRepository();
  });

  test('GetOrInitFeedLoadedAtUseCase delegates', () async {
    final ts = DateTime(2026, 1, 1);
    when(() => repo.getOrInitFeedLoadedAt()).thenAnswer((_) async => Right(ts));

    final result = await GetOrInitFeedLoadedAtUseCase(repo).call();

    expect(result, Right<Failure, DateTime>(ts));
  });

  test('SetFeedLoadedAtUseCase forwards the timestamp', () async {
    final ts = DateTime(2026, 1, 1);
    when(() => repo.setFeedLoadedAt(ts)).thenAnswer((_) async => const Right(unit));

    await SetFeedLoadedAtUseCase(repo).call(ts);

    verify(() => repo.setFeedLoadedAt(ts)).called(1);
  });

  test('GetUnreadPageUseCase forwards limit + excludeIds', () async {
    when(() => repo.getUnread(limit: 20, excludeIds: {'a'}))
        .thenAnswer((_) async => Right([aNote()]));

    await GetUnreadPageUseCase(repo).call(const UnreadPageInput(limit: 20, excludeIds: {'a'}));

    verify(() => repo.getUnread(limit: 20, excludeIds: {'a'})).called(1);
  });

  test('GetSeenPageUseCase forwards limit + before', () async {
    final before = DateTime(2026, 1, 1);
    when(() => repo.getSeen(limit: 20, before: before))
        .thenAnswer((_) async => Right([aNote()]));

    await GetSeenPageUseCase(repo).call(SeenPageInput(limit: 20, before: before));

    verify(() => repo.getSeen(limit: 20, before: before)).called(1);
  });

  test('WatchNewBufferCountUseCase forwards loadedAt', () {
    final loadedAt = DateTime(2026, 1, 1);
    when(() => repo.watchNewBufferCount(loadedAt)).thenAnswer((_) => Stream.value(3));

    final stream = WatchNewBufferCountUseCase(repo).call(loadedAt);

    expect(stream, isA<Stream<int>>());
    verify(() => repo.watchNewBufferCount(loadedAt)).called(1);
  });

  test('MarkFeedItemSeenUseCase delegates to markSeen', () async {
    when(() => repo.markSeen('n1')).thenAnswer((_) async => const Right(unit));

    final result = await MarkFeedItemSeenUseCase(repo).call('n1');

    expect(result, const Right<Failure, Unit>(unit));
  });
}
