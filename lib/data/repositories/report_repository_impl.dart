import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/report_model.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/report_repository.dart';
import 'package:uniun/domain/repositories/user_repository.dart';

@Injectable(as: ReportRepository)
class ReportRepositoryImpl extends ReportRepository {
  final Isar _isar;
  final EventQueueRepository _eventQueueRepository;
  final UserRepository _userRepository;

  ReportRepositoryImpl({
    required Isar isar,
    required EventQueueRepository eventQueueRepository,
    required UserRepository userRepository,
  })  : _isar = isar,
        _eventQueueRepository = eventQueueRepository,
        _userRepository = userRepository;

  @override
  Future<Either<Failure, ReportEntity>> reportNote({
    required String targetEventId,
    required String targetPubkey,
    required ReportType type,
    String content = '',
  }) {
    return _publish(
      targetEventId: targetEventId,
      targetPubkey: targetPubkey,
      type: type,
      content: content,
    );
  }

  @override
  Future<Either<Failure, ReportEntity>> reportUser({
    required String targetPubkey,
    required ReportType type,
    String content = '',
  }) {
    return _publish(
      targetEventId: null,
      targetPubkey: targetPubkey,
      type: type,
      content: content,
    );
  }

  Future<Either<Failure, ReportEntity>> _publish({
    required String? targetEventId,
    required String targetPubkey,
    required ReportType type,
    required String content,
  }) async {
    try {
      final keys = await _userRepository.getActiveKeysHex();
      if (keys == null) {
        return const Left(Failure.errorFailure(
            'Cannot report — no active identity loaded'));
      }

      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // NIP-56 tag shape — `e` (when reporting a note) and `p` carry the
      // report type as their last positional entry. Tag order must match
      // EventQueueModel.toSerializedRelayMessage so the signature survives
      // the queue's re-serialization.
      final tags = <List<String>>[
        if (targetEventId != null) ['e', targetEventId, '', type.name],
        ['p', targetPubkey, type.name],
      ];

      final event = Event.from(
        privkey: keys.privkeyHex,
        kind: kReportKind,
        content: content,
        tags: tags,
        createdAt: createdAt,
      );

      final created =
          DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000);

      final row = ReportModel()
        ..eventId = event.id
        ..reportType = type.name
        ..targetEventId = targetEventId
        ..targetPubkey = targetPubkey
        ..content = content
        ..created = created;

      await _isar.writeTxn(() async {
        await _isar.reportModels.put(row);
      });

      final enqueueResult = await _eventQueueRepository.enqueueSignedEvent(
        eventId: event.id,
        authorPubkey: event.pubkey,
        sig: event.sig,
        kind: kReportKind,
        eTagRefs: targetEventId != null ? [targetEventId] : const [],
        pTagRefs: [targetPubkey],
        tTags: const [],
        content: content,
        created: created,
        reportType: type.name,
      );
      if (enqueueResult.isLeft()) {
        return Left(enqueueResult.fold(
          (f) => f,
          (_) => const Failure.errorFailure('enqueue failed'),
        ));
      }

      return Right(row.toDomain());
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }
}
