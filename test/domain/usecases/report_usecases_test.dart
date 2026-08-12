import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';
import 'package:uniun/domain/repositories/report_repository.dart';
import 'package:uniun/domain/usecases/report_usecases.dart';

class _MockReportRepository extends Mock implements ReportRepository {}

ReportEntity _aReport() => ReportEntity(
      eventId: 'report-1',
      type: ReportType.spam,
      targetPubkey: 'pk',
      content: '',
      created: DateTime(2026, 1, 1),
    );

void main() {
  late _MockReportRepository repo;

  setUp(() {
    repo = _MockReportRepository();
  });

  test('ReportNoteUseCase forwards every field', () async {
    when(() => repo.reportNote(
          targetEventId: 'evt-1',
          targetPubkey: 'pk',
          type: ReportType.spam,
          content: 'spammy',
        )).thenAnswer((_) async => Right(_aReport()));

    final result = await ReportNoteUseCase(repo).call(const ReportNoteInput(
      targetEventId: 'evt-1',
      targetPubkey: 'pk',
      type: ReportType.spam,
      content: 'spammy',
    ));

    expect(result.isRight(), isTrue);
    verify(() => repo.reportNote(
          targetEventId: 'evt-1',
          targetPubkey: 'pk',
          type: ReportType.spam,
          content: 'spammy',
        )).called(1);
  });

  test('ReportUserUseCase forwards every field', () async {
    when(() => repo.reportUser(
          targetPubkey: 'pk',
          type: ReportType.impersonation,
          content: 'fake account',
        )).thenAnswer((_) async => Right(_aReport()));

    final result = await ReportUserUseCase(repo).call(const ReportUserInput(
      targetPubkey: 'pk',
      type: ReportType.impersonation,
      content: 'fake account',
    ));

    expect(result.isRight(), isTrue);
    verify(() => repo.reportUser(
          targetPubkey: 'pk',
          type: ReportType.impersonation,
          content: 'fake account',
        )).called(1);
  });
}
