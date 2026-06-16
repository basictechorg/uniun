import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';

@Injectable(as: EventQueueRepository)
class EventQueueRepositoryImpl extends EventQueueRepository {
  final Isar isar;
  EventQueueRepositoryImpl({required this.isar});

  @override
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
    String? hTag,
    String? dTag,
    int? expirationSec,
    List<String> serverTags = const [],
    List<MediaBlobEntity> imeta = const [],
  }) async {
    try {
      final existing = await isar.eventQueueModels
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
      if (existing != null) {
        return Right(existing.id);
      }

      final row = EventQueueModel()
        ..eventId = eventId
        ..authorPubkey = authorPubkey
        ..sig = sig
        ..kind = kind
        ..eTagRefs = List<String>.from(eTagRefs)
        ..rootEventId = rootEventId
        ..replyToEventId = replyToEventId
        ..pTagRefs = List<String>.from(pTagRefs)
        ..tTags = List<String>.from(tTags)
        ..content = content
        ..created = created
        ..quoteEventId = quoteEventId
        ..quoteAuthorPubkey = quoteAuthorPubkey
        ..quoteKind = quoteKind
        ..hTag = hTag
        ..dTag = dTag
        ..expirationSec = expirationSec
        ..serverTags = List<String>.from(serverTags)
        ..imeta = imeta
            .map((b) => MediaAttachment()
              ..sha256 = b.sha256
              ..mime = b.mime
              ..sizeBytes = b.sizeBytes
              ..url = b.serverUrls.isNotEmpty ? b.serverUrls.first : null
              ..width = b.dim?.width
              ..height = b.dim?.height
              ..blurhash = b.blurhash
              ..filename = b.filename)
            .toList()
        ..sentCount = 0
        ..enqueuedAt = DateTime.now();

      late int id;
      await isar.writeTxn(() async {
        id = await isar.eventQueueModels.put(row);
      });
      return Right(id);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
