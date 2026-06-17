import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/shiv/scored_note.dart';
import 'package:uniun/domain/repositories/vector_repository.dart';
import 'package:uniun/domain/usecases/knowledge_usecases.dart';
import 'package:uniun/features/shiv/rag/embedding/embedding_service.dart';

@lazySingleton
class SearchVectorNotesUseCase
    extends UseCase<Either<Failure, List<ScoredNote>>, (List<double>, int, double)> {
  final VectorRepository _repository;

  SearchVectorNotesUseCase(this._repository);

  @override
  Future<Either<Failure, List<ScoredNote>>> call(
      (List<double>, int, double) input,
      {bool cached = false}) async {
    try {
      final (vec, topK, minScore) = input;
      final result = await _repository.search(vec, topK: topK, minScore: minScore);
      return Right(result);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}

/// Embeds [content] via [EmbeddingService] and persists the vector via
/// [VectorRepository]. Single use case — callers never touch EmbeddingService.
///
/// Input: (eventId, raw nostr content) tuple. The use case strips media URLs
/// (NIP-92 attachments embed their URL into `content`) and skips entirely
/// when no text remains — image-only / video-only notes have nothing
/// meaningful to embed for RAG.
///
/// Fire-and-forget safe — returns void, silently no-ops if model not ready
/// or there is nothing to embed.
@lazySingleton
class EmbedAndStoreNoteUseCase
    extends UseCase<void, (String, String)> {
  final EmbeddingService _embedding;
  final VectorRepository _vector;
  final ExtractKnowledgeUseCase _extract;

  EmbedAndStoreNoteUseCase(this._embedding, this._vector, this._extract);

  /// Strips http(s) URLs from `content`. Media notes carry their blob URL
  /// inline; embedding it produces a useless vector. A typed caption like
  /// "check this article: https://…" survives with the prose intact.
  static final _urlPattern = RegExp(r'https?://\S+', caseSensitive: false);

  /// Below this many post-strip characters there is no signal worth a
  /// vector — punctuation, single emojis, or empty captions all skip.
  static const int _minEmbeddableChars = 4;

  @override
  Future<void> call((String, String) input, {bool cached = false}) async {
    final (eventId, rawContent) = input;
    final shortId = eventId.length > 8 ? eventId.substring(0, 8) : eventId;
    final text = rawContent.replaceAll(_urlPattern, '').trim();
    if (text.length < _minEmbeddableChars) {
      debugPrint('🧠 EmbedAndStore: skip note=$shortId (no embeddable text — '
          'media-only or empty after URL strip)');
      return;
    }
    debugPrint('🧠 EmbedAndStore: start note=$shortId chars=${text.length}');
    try {
      final vec = await _embedding.embed(text, isDocument: true);
      if (vec.isEmpty) {
        debugPrint('⚠️ EmbedAndStore: embed returned empty vector for $shortId');
        return;
      }
      debugPrint('🧠 EmbedAndStore: embedded (dim=${vec.length}), upserting to Tostore…');
      await _vector.upsert(eventId, vec);
      debugPrint('✅ EmbedAndStore: Tostore upsert OK for $shortId');
      unawaited(_extract.call((eventId, text, vec)));
    } catch (e, st) {
      debugPrint('❌ EmbedAndStore failed for $shortId: $e\n$st');
    }
  }
}
