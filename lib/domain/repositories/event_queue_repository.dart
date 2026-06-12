import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';

abstract class EventQueueRepository {
  /// Enqueue one signed event payload for relay publication.
  ///
  /// Returns the Isar row id on success.
  Future<Either<Failure, int>> enqueueSignedEvent({
    required String eventId,
    required String authorPubkey,
    required String sig,
    required int kind,
    required List<String> eTagRefs,
    String? rootEventId,
    String? replyToEventId,
    required List<String> pTagRefs,
    required List<String> tTags,
    required String content,
    required DateTime created,
    String? quoteEventId,
    String? quoteAuthorPubkey,
    int? quoteKind,
    bool rawPassthrough,
  });
}
