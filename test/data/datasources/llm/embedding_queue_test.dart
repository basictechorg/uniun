import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/datasources/llm/embedding_queue.dart';

void main() {
  group('EmbeddingQueue — bounded concurrency', () {
    test('caps in-flight at 2 (Semaphore(2))', () async {
      final q = EmbeddingQueue();
      var maxInFlight = 0;
      var current = 0;

      Future<void> task() async {
        current++;
        if (current > maxInFlight) maxInFlight = current;
        await Future.delayed(const Duration(milliseconds: 30));
        current--;
      }

      // Fire 6 concurrent — the cap should hold them to 2 at a time.
      await Future.wait(List.generate(6, (_) => q.run(task)));
      expect(maxInFlight, equals(2));
    });

    test('semaphore released even when work throws', () async {
      final q = EmbeddingQueue();

      // First two slots used by throwing work.
      await Future.wait([
        q.run(() => Future<void>.error(Exception('boom1'))).catchError((_) {}),
        q.run(() => Future<void>.error(Exception('boom2'))).catchError((_) {}),
      ]);

      // After failures, the queue should still admit new work — if the
      // semaphore had leaked we'd hang here.
      final ok = await q.run<int>(() async => 42).timeout(
            const Duration(seconds: 1),
          );
      expect(ok, equals(42));
    });

    test('returns work result correctly', () async {
      final q = EmbeddingQueue();
      final result = await q.run<String>(() async => 'hello');
      expect(result, equals('hello'));
    });

    test('waiters are released in FIFO order', () async {
      final q = EmbeddingQueue();
      final order = <int>[];

      // Pin the two slots with long-running work.
      final pin1 = q.run<void>(() async {
        await Future.delayed(const Duration(milliseconds: 80));
        order.add(1);
      });
      final pin2 = q.run<void>(() async {
        await Future.delayed(const Duration(milliseconds: 80));
        order.add(2);
      });
      // Brief pause so 1 + 2 are definitely "in flight".
      await Future.delayed(const Duration(milliseconds: 10));

      // Now queue 3 → 4 → 5. They should release in that order as slots free.
      final w3 = q.run<void>(() async {
        order.add(3);
      });
      final w4 = q.run<void>(() async {
        order.add(4);
      });
      final w5 = q.run<void>(() async {
        order.add(5);
      });

      await Future.wait([pin1, pin2, w3, w4, w5]);

      // 1 and 2 land first (in any order — both running concurrently), then
      // 3 / 4 / 5 strictly in FIFO order of arrival.
      expect(order.where((n) => n > 2).toList(), equals([3, 4, 5]));
    });
  });
}
