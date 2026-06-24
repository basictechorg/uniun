import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

abstract class EventQueueRepository {
  /// Enqueue one signed event payload for relay publication.
  ///
  /// Caller must sign in the canonical tag order documented in
  /// `EventQueueModel.toSerializedRelayMessage` — otherwise the relay's
  /// signature check will reject the event when the queue re-serializes it.
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
    String? embeddedNoteJson,
    int? quoteKind,
    String? hTag,
    String? dTag,
    int? expirationSec,
    List<String> serverTags,
    List<MediaBlobEntity> imeta,
    String? reportType,
  });
}
