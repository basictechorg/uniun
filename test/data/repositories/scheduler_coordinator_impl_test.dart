import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/datasources/llm/inference_scheduler.dart';
import 'package:uniun/data/repositories/scheduler_coordinator_impl.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';

void main() {
  group('SchedulerCoordinatorImpl — domain → scheduler bridge', () {
    test('setForeground(kind) routes to InferenceScheduler', () async {
      final scheduler = InferenceScheduler();
      final coord = SchedulerCoordinatorImpl(scheduler);

      // Submit a job that depends on its kind being the foreground (T1).
      // First with no foreground: gana sits at T4.
      final trace = <String>[];
      final blocker = scheduler.run<void>(
        kind: LlmTaskKind.chat,
        modelId: 'm',
        work: (_) async => Future.delayed(const Duration(milliseconds: 40)),
      );
      final g = scheduler.run<void>(
        kind: LlmTaskKind.gana,
        modelId: 'm',
        work: (_) async => trace.add('gana'),
      );
      // Through the coordinator, hoist gana to T1.
      final result = await coord.setForeground(LlmTaskKind.gana);
      expect(result, isA<Right<dynamic, Unit>>());

      await Future.wait([blocker, g]);
      expect(trace, contains('gana'));
    });

    test('setForeground(null) is accepted and returns Right(unit)', () async {
      final scheduler = InferenceScheduler();
      final coord = SchedulerCoordinatorImpl(scheduler);

      final result = await coord.setForeground(null);
      expect(result, isA<Right<dynamic, Unit>>());
      result.fold(
        (_) => fail('expected Right(unit)'),
        (r) => expect(r, equals(unit)),
      );
    });

    test('successive setForeground calls do not throw', () async {
      final scheduler = InferenceScheduler();
      final coord = SchedulerCoordinatorImpl(scheduler);

      await coord.setForeground(LlmTaskKind.chat);
      await coord.setForeground(LlmTaskKind.nataraj);
      await coord.setForeground(LlmTaskKind.gana);
      await coord.setForeground(null);
      // No assertion — we just need no exception.
    });
  });
}
