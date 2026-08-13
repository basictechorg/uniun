import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/repositories/nataraj_repository.dart';
import 'package:uniun/domain/usecases/nataraj_usecases.dart';

class _MockNatarajRepository extends Mock implements NatarajRepository {}

NatarajCardEntity _aCard() => NatarajCardEntity(
      scopeId: 'all',
      signature: 'sig-1',
      noteIds: const ['a', 'b'],
      generatedParagraph: 'a synthesis',
      status: NatarajCardStatus.buffered,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockNatarajRepository repo;

  setUp(() {
    repo = _MockNatarajRepository();
  });

  test('GetNextNatarajCardUseCase delegates to nextBufferedCard', () async {
    when(() => repo.nextBufferedCard('all')).thenAnswer((_) async => Right(_aCard()));

    final result = await GetNextNatarajCardUseCase(repo).call('all');

    expect(result.isRight(), isTrue);
  });

  test('RecordNatarajSwipeUseCase forwards every field', () async {
    when(() => repo.updateStatus('all', 'sig-1', NatarajCardStatus.published))
        .thenAnswer((_) async => const Right(unit));

    final result = await RecordNatarajSwipeUseCase(repo).call(const RecordNatarajSwipeInput(
      scopeId: 'all',
      signature: 'sig-1',
      status: NatarajCardStatus.published,
    ));

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repo.updateStatus('all', 'sig-1', NatarajCardStatus.published)).called(1);
  });

  test('CountBufferedNatarajCardsUseCase counts only buffered cards',
      () async {
    when(() => repo.countByStatus('all', NatarajCardStatus.buffered))
        .thenAnswer((_) async => const Right(3));

    final result = await CountBufferedNatarajCardsUseCase(repo).call('all');

    expect(result, const Right<Failure, int>(3));
    verify(() => repo.countByStatus('all', NatarajCardStatus.buffered)).called(1);
  });
}
