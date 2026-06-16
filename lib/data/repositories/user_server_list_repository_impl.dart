import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/user_server_list_repository.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

const int _kUserServerListKind = 10063;

@Injectable(as: UserServerListRepository)
class UserServerListRepositoryImpl extends UserServerListRepository {
  UserServerListRepositoryImpl({
    required UserServerListStore store,
    required EventQueueRepository eventQueue,
    required GetActiveUserKeysUseCase getActiveUserKeys,
  })  : _store = store,
        _eventQueue = eventQueue,
        _getActiveUserKeys = getActiveUserKeys;

  final UserServerListStore _store;
  final EventQueueRepository _eventQueue;
  final GetActiveUserKeysUseCase _getActiveUserKeys;

  @override
  Future<Either<Failure, List<String>>> getServers() async {
    try {
      final servers = _store.servers;
      if (servers.isEmpty) {
        return const Right([AppConstants.kUniunBlossom]);
      }
      return Right(servers);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setServers(List<String> serverUrls) async {
    try {
      await _store.setServers(serverUrls);
      await _publishServerList(serverUrls);
      return const Right(unit);
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<void> _publishServerList(List<String> serverUrls) async {
    try {
      final keysResult = await _getActiveUserKeys.call();
      final keys = keysResult.fold((_) => null, (k) => k);
      if (keys == null) return;

      final tags = <List<String>>[
        for (final url in serverUrls) ['server', url],
      ];
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event.from(
        kind: _kUserServerListKind,
        tags: tags,
        content: '',
        privkey: keys.privkeyHex,
        createdAt: nowSec,
      );

      await _eventQueue.enqueueSignedEvent(
        eventId: event.id,
        authorPubkey: event.pubkey,
        sig: event.sig,
        kind: _kUserServerListKind,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        content: event.content,
        created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        serverTags: serverUrls,
      );
    } catch (_) {
      // Best-effort publish — local snapshot is authoritative.
    }
  }
}
