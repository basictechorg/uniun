import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/domain/entities/shiv/scored_note.dart';
import 'package:uniun/domain/repositories/vector_repository.dart';
import 'package:uniun/domain/usecases/knowledge_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/shiv/rag/embedding/embedding_service.dart';

class _MockVectorRepository extends Mock implements VectorRepository {}

class _MockEmbeddingService extends Mock implements EmbeddingService {}

class _MockExtractKnowledge extends Mock implements ExtractKnowledgeUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(('', '', <double>[]));
  });

  group('SearchVectorNotesUseCase', () {
    late _MockVectorRepository repo;

    setUp(() {
      repo = _MockVectorRepository();
    });

    test(
      'forwards vector/topK/minScore and wraps the result in Right',
      () async {
        when(() => repo.search([1.0, 2.0], topK: 5, minScore: 0.3)).thenAnswer(
          (_) async => const [
            ScoredNote(noteId: 'n1', score: 0.9, content: 'hit'),
          ],
        );

        final result = await SearchVectorNotesUseCase(
          repo,
        ).call(([1.0, 2.0], 5, 0.3));

        expect(result.getOrElse(() => []), hasLength(1));
        verify(() => repo.search([1.0, 2.0], topK: 5, minScore: 0.3)).called(1);
      },
    );

    test(
      'a repository throw degrades to Left, not an uncaught exception',
      () async {
        when(
          () => repo.search(
            any(),
            topK: any(named: 'topK'),
            minScore: any(named: 'minScore'),
          ),
        ).thenThrow(Exception('index unavailable'));

        final result = await SearchVectorNotesUseCase(
          repo,
        ).call(([1.0], 5, 0.3));

        expect(result.isLeft(), isTrue);
      },
    );
  });

  group('EmbedAndStoreNoteUseCase', () {
    late _MockEmbeddingService embedding;
    late _MockVectorRepository vector;
    late _MockExtractKnowledge extract;

    setUp(() {
      embedding = _MockEmbeddingService();
      vector = _MockVectorRepository();
      extract = _MockExtractKnowledge();
    });

    test(
      'skips entirely when the content is too short after URL stripping',
      () async {
        await EmbedAndStoreNoteUseCase(
          embedding,
          vector,
          extract,
        ).call(('n1', 'https://example.com/x'));

        verifyZeroInteractions(embedding);
        verifyZeroInteractions(vector);
      },
    );

    test('embeds the URL-stripped text and upserts, then fires knowledge '
        'extraction', () async {
      when(
        () => embedding.embed(any(), isDocument: any(named: 'isDocument')),
      ).thenAnswer((_) async => [0.1, 0.2]);
      when(() => vector.upsert('n1', [0.1, 0.2])).thenAnswer((_) async {});
      when(() => extract.call(any())).thenAnswer((_) async {});

      await EmbedAndStoreNoteUseCase(
        embedding,
        vector,
        extract,
      ).call(('n1', 'a real caption https://example.com/img.png'));

      verify(
        () => embedding.embed('a real caption', isDocument: true),
      ).called(1);
      verify(() => vector.upsert('n1', [0.1, 0.2])).called(1);
      await Future<void>.delayed(Duration.zero);
      // A record field's `==` is identity-based for the embedded List, so a
      // literal-tuple match would never equal the tuple built by production
      // code — capture and compare fields instead.
      final captured =
          verify(
                () => extract.call(captureAny(), cached: any(named: 'cached')),
              ).captured.single
              as (String, String, List<double>);
      expect(captured.$1, 'n1');
      expect(captured.$2, 'a real caption');
      expect(captured.$3, [0.1, 0.2]);
    });

    test('an empty embedding vector skips the upsert and extraction', () async {
      when(
        () => embedding.embed(any(), isDocument: any(named: 'isDocument')),
      ).thenAnswer((_) async => <double>[]);

      await EmbedAndStoreNoteUseCase(
        embedding,
        vector,
        extract,
      ).call(('n1', 'some text'));

      verifyZeroInteractions(vector);
      verifyZeroInteractions(extract);
    });

    test('an embedding failure is caught, not rethrown', () async {
      when(
        () => embedding.embed(any(), isDocument: any(named: 'isDocument')),
      ).thenThrow(Exception('model not loaded'));

      await EmbedAndStoreNoteUseCase(
        embedding,
        vector,
        extract,
      ).call(('n1', 'some text'));

      verifyZeroInteractions(vector);
    });
  });
}
