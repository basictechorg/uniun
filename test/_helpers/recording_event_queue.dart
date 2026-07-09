import 'package:dartz/dartz.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';

/// Shared [EventQueueRepository] test double.
///
/// Captures every call to [enqueueSignedEvent] so tests can assert on the
/// exact wire-shape produced by the repo under test (kind, tag lists,
/// content, report type, imeta blobs, etc). Configure the response via
/// [leftOnEnqueue] (returns Left) or [throwOnEnqueue] (throws) to simulate
/// the two failure modes.
///
/// Extracted from three separate hand-rolls in
/// `draft_repository_test.dart`, `report_repository_impl_test.dart` and
/// `followed_user_repository_impl_test.dart`.
class RecordingEventQueue implements EventQueueRepository {
  final List<EnqueueCall> calls = [];
  Failure? leftOnEnqueue;
  bool throwOnEnqueue = false;

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
    String? embeddedNoteJson,
    int? quoteKind,
    String? hTag,
    String? dTag,
    int? expirationSec,
    List<String> serverTags = const [],
    List<MediaBlobEntity> imeta = const [],
    String? reportType,
  }) async {
    if (throwOnEnqueue) throw StateError('relay down');
    if (leftOnEnqueue != null) return Left(leftOnEnqueue!);
    calls.add(EnqueueCall(
      eventId: eventId,
      authorPubkey: authorPubkey,
      sig: sig,
      kind: kind,
      eTagRefs: eTagRefs,
      pTagRefs: pTagRefs,
      tTags: tTags,
      content: content,
      created: created,
      dTag: dTag,
      hTag: hTag,
      embeddedNoteJson: embeddedNoteJson,
      reportType: reportType,
      serverTags: serverTags,
      imeta: imeta,
    ));
    return const Right(1);
  }
}

/// One captured [EventQueueRepository.enqueueSignedEvent] call. Only the
/// fields tests currently assert on are stored — extend as needed.
class EnqueueCall {
  EnqueueCall({
    required this.eventId,
    required this.authorPubkey,
    required this.sig,
    required this.kind,
    required this.eTagRefs,
    required this.pTagRefs,
    required this.tTags,
    required this.content,
    required this.created,
    this.dTag,
    this.hTag,
    this.embeddedNoteJson,
    this.reportType,
    this.serverTags = const [],
    this.imeta = const [],
  });

  final String eventId;
  final String authorPubkey;
  final String sig;
  final int kind;
  final List<String> eTagRefs;
  final List<String> pTagRefs;
  final List<String> tTags;
  final String content;
  final DateTime created;
  final String? dTag;
  final String? hTag;
  final String? embeddedNoteJson;
  final String? reportType;
  final List<String> serverTags;
  final List<MediaBlobEntity> imeta;
}
