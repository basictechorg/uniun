import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/storage/storage_stats.dart';
import 'package:uniun/domain/repositories/storage_repository.dart';
import 'package:uniun/domain/usecases/storage_usecases.dart';

class _MockStorageRepository extends Mock implements StorageRepository {}

const _aStats = StorageStats(
  dbSizeBytes: 1,
  modelSizeBytes: 2,
  chatHistorySizeBytes: 3,
  mediaSizeBytes: 4,
  otherSizeBytes: 5,
  totalNoteCount: 6,
  deletableFeedNoteCount: 7,
  conversationCount: 8,
  freeDiskBytes: 9,
);

void main() {
  late _MockStorageRepository repo;

  setUp(() {
    repo = _MockStorageRepository();
  });

  test('GetStorageStatsUseCase forwards the owner pubkey', () async {
    when(() => repo.getStats('pk')).thenAnswer((_) async => const Right(_aStats));

    final result = await GetStorageStatsUseCase(repo).call('pk');

    expect(result, const Right<Failure, StorageStats>(_aStats));
  });

  test('DeleteFeedNotesUseCase forwards the owner pubkey', () async {
    when(() => repo.deleteFeedNotes('pk')).thenAnswer((_) async => const Right(42));

    final result = await DeleteFeedNotesUseCase(repo).call('pk');

    expect(result, const Right<Failure, int>(42));
  });

  test('DeleteAllChatHistoryUseCase delegates to deleteAllChatHistory',
      () async {
    when(() => repo.deleteAllChatHistory()).thenAnswer((_) async => const Right(unit));

    final result = await DeleteAllChatHistoryUseCase(repo).call();

    expect(result, const Right<Failure, Unit>(unit));
  });
}
