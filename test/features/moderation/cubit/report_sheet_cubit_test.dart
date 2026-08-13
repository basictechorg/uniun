import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';
import 'package:uniun/domain/usecases/report_usecases.dart';
import 'package:uniun/features/moderation/cubit/report_sheet_cubit.dart';

class _MockReportNote extends Mock implements ReportNoteUseCase {}

class _MockReportUser extends Mock implements ReportUserUseCase {}

ReportEntity _aReport() => ReportEntity(
      eventId: 'report-1',
      type: ReportType.spam,
      targetPubkey: 'pk',
      content: '',
      created: DateTime(2026, 1, 1),
    );

/// Covers: ReportSheetCubit's field reducers, submit's note-vs-profile
/// dispatch (routes to ReportNoteUseCase when targetEventId is set, else
/// ReportUserUseCase), the no-type-selected guard, and both the success and
/// failure outcomes.
void main() {
  late _MockReportNote reportNote;
  late _MockReportUser reportUser;
  late GetIt getIt;

  setUpAll(() {
    registerFallbackValue(const ReportNoteInput(
      targetEventId: '',
      targetPubkey: '',
      type: ReportType.other,
    ));
    registerFallbackValue(const ReportUserInput(targetPubkey: '', type: ReportType.other));
  });

  setUp(() async {
    getIt = GetIt.instance;
    await getIt.reset();
    reportNote = _MockReportNote();
    reportUser = _MockReportUser();
    getIt.registerFactory<ReportNoteUseCase>(() => reportNote);
    getIt.registerFactory<ReportUserUseCase>(() => reportUser);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('field reducers', () {
    blocTest<ReportSheetCubit, ReportSheetState>(
      'pickType sets the type',
      build: () => ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk'),
      act: (c) => c.pickType(ReportType.spam),
      expect: () => [
        isA<ReportSheetState>().having((s) => s.type, 'type', ReportType.spam),
      ],
    );

    blocTest<ReportSheetCubit, ReportSheetState>(
      'setReason sets the free-text reason',
      build: () => ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk'),
      act: (c) => c.setReason('spammy content'),
      expect: () => [
        isA<ReportSheetState>().having((s) => s.reason, 'reason', 'spammy content'),
      ],
    );

    blocTest<ReportSheetCubit, ReportSheetState>(
      'toggleAlsoBlock flips the block flag',
      build: () => ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk'),
      act: (c) => c.toggleAlsoBlock(true),
      expect: () => [
        isA<ReportSheetState>().having((s) => s.alsoBlock, 'alsoBlock', true),
      ],
    );
  });

  group('canSubmit', () {
    test('false with no type selected, or while submitting', () {
      expect(const ReportSheetState().canSubmit, isFalse);
      expect(const ReportSheetState(type: ReportType.spam).canSubmit, isTrue);
      expect(
        const ReportSheetState(type: ReportType.spam, status: ReportSheetStatus.submitting).canSubmit,
        isFalse,
      );
    });
  });

  group('submit', () {
    blocTest<ReportSheetCubit, ReportSheetState>(
      'with no type selected: a no-op, never touching either use case',
      build: () => ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk'),
      act: (c) => c.submit(),
      expect: () => <ReportSheetState>[],
      verify: (_) {
        verifyZeroInteractions(reportNote);
        verifyZeroInteractions(reportUser);
      },
    );

    blocTest<ReportSheetCubit, ReportSheetState>(
      'a note target routes through ReportNoteUseCase with the reason and '
      'type, reaching submitted on success',
      build: () {
        when(() => reportNote.call(any())).thenAnswer((_) async => Right(_aReport()));
        return ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk');
      },
      seed: () => const ReportSheetState(type: ReportType.spam, reason: 'spammy'),
      act: (c) => c.submit(),
      expect: () => [
        isA<ReportSheetState>().having((s) => s.status, 'status', ReportSheetStatus.submitting),
        isA<ReportSheetState>().having((s) => s.status, 'status', ReportSheetStatus.submitted),
      ],
      verify: (_) {
        final input = verify(() => reportNote.call(captureAny())).captured.single as ReportNoteInput;
        expect(input.targetEventId, 'n1');
        expect(input.targetPubkey, 'pk');
        expect(input.type, ReportType.spam);
        expect(input.content, 'spammy');
        verifyZeroInteractions(reportUser);
      },
    );

    blocTest<ReportSheetCubit, ReportSheetState>(
      'a null targetEventId (profile-only report) routes through '
      'ReportUserUseCase instead',
      build: () {
        when(() => reportUser.call(any())).thenAnswer((_) async => Right(_aReport()));
        return ReportSheetCubit(targetEventId: null, targetPubkey: 'pk');
      },
      seed: () => const ReportSheetState(type: ReportType.impersonation),
      act: (c) => c.submit(),
      expect: () => [
        isA<ReportSheetState>().having((s) => s.status, 'status', ReportSheetStatus.submitting),
        isA<ReportSheetState>().having((s) => s.status, 'status', ReportSheetStatus.submitted),
      ],
      verify: (_) {
        final input = verify(() => reportUser.call(captureAny())).captured.single as ReportUserInput;
        expect(input.targetPubkey, 'pk');
        expect(input.type, ReportType.impersonation);
        verifyZeroInteractions(reportNote);
      },
    );

    blocTest<ReportSheetCubit, ReportSheetState>(
      'a repository failure surfaces as an error status with a message',
      build: () {
        when(() => reportNote.call(any()))
            .thenAnswer((_) async => const Left(Failure.errorFailure('relay down')));
        return ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk');
      },
      seed: () => const ReportSheetState(type: ReportType.spam),
      act: (c) => c.submit(),
      expect: () => [
        isA<ReportSheetState>().having((s) => s.status, 'status', ReportSheetStatus.submitting),
        isA<ReportSheetState>()
            .having((s) => s.status, 'status', ReportSheetStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );

    blocTest<ReportSheetCubit, ReportSheetState>(
      'does not emit after the cubit is closed mid-submit',
      build: () {
        when(() => reportNote.call(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return Right(_aReport());
        });
        return ReportSheetCubit(targetEventId: 'n1', targetPubkey: 'pk');
      },
      seed: () => const ReportSheetState(type: ReportType.spam),
      act: (c) {
        // fire-and-forget: submit() awaits a 50ms use case call; closing
        // the cubit before it resolves must not throw "emit after close".
        unawaited(c.submit());
      },
      wait: const Duration(milliseconds: 10),
    );
  });
}
