import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/domain/entities/private_group/private_group_join_request_entity.dart';
import 'package:uniun/domain/repositories/e2ee_group_repository.dart';
import 'package:uniun/domain/services/marmot_transport_service.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockMarmotTransportService extends Mock
    implements MarmotTransportService {}

class _MockE2EEGroupRepository extends Mock implements E2EEGroupRepository {}

void main() {
  late _MockMarmotTransportService transport;
  late _MockE2EEGroupRepository repo;

  setUp(() {
    transport = _MockMarmotTransportService();
    repo = _MockE2EEGroupRepository();
  });

  test('CreatePrivateGroupUsecase forwards every field and returns the '
      'group id', () async {
    when(() => transport.createGroup(
          privkeyHex: any(named: 'privkeyHex'),
          authorPubkey: any(named: 'authorPubkey'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          relays: any(named: 'relays'),
        )).thenAnswer((_) async => 'group-1');

    final result = await CreatePrivateGroupUsecase(transport).execute(
      privkeyHex: 'pk',
      authorPubkey: 'author',
      name: 'Secret',
      description: 'desc',
      relays: const ['wss://relay.example'],
    );

    expect(result, 'group-1');
    verify(() => transport.createGroup(
          privkeyHex: 'pk',
          authorPubkey: 'author',
          name: 'Secret',
          description: 'desc',
          relays: const ['wss://relay.example'],
        )).called(1);
  });

  test('GetPrivateGroupsUsecase forwards to watchGroups', () {
    when(() => repo.watchGroups()).thenAnswer((_) => Stream.value([aPrivateGroup()]));

    final stream = GetPrivateGroupsUsecase(repo).execute();

    expect(stream, isA<Stream<List<dynamic>>>());
    verify(() => repo.watchGroups()).called(1);
  });

  group('GetPrivateGroupEntityUsecase', () {
    test('returns the matching group from the first watchGroups emission',
        () async {
      when(() => repo.watchGroups()).thenAnswer(
          (_) => Stream.value([aPrivateGroup(groupId: 'g1'), aPrivateGroup(groupId: 'g2')]));

      final result = await GetPrivateGroupEntityUsecase(repo).execute('g2');

      expect(result?.groupId, 'g2');
    });

    test('returns null when no group matches', () async {
      when(() => repo.watchGroups()).thenAnswer((_) => Stream.value([aPrivateGroup(groupId: 'g1')]));

      final result = await GetPrivateGroupEntityUsecase(repo).execute('missing');

      expect(result, isNull);
    });

    test('watch() maps each emission to the matching group or null', () async {
      when(() => repo.watchGroups()).thenAnswer(
          (_) => Stream.value([aPrivateGroup(groupId: 'g1')]));

      final result = await GetPrivateGroupEntityUsecase(repo).watch('g1').first;

      expect(result?.groupId, 'g1');
    });
  });

  test('GetPrivateGroupMessagesUsecase forwards to watchMessages', () {
    when(() => repo.watchMessages('g1')).thenAnswer((_) => Stream.value([aNote()]));

    final stream = GetPrivateGroupMessagesUsecase(repo).execute('g1');

    expect(stream, isA<Stream<List<dynamic>>>());
    verify(() => repo.watchMessages('g1')).called(1);
  });

  test('GetPrivateGroupJoinRequestsUsecase forwards to watchJoinRequests',
      () {
    when(() => repo.watchJoinRequests('g1'))
        .thenAnswer((_) => Stream.value(<PrivateGroupJoinRequestEntity>[]));

    final stream = GetPrivateGroupJoinRequestsUsecase(repo).execute('g1');

    expect(stream, isA<Stream<List<PrivateGroupJoinRequestEntity>>>());
    verify(() => repo.watchJoinRequests('g1')).called(1);
  });

  test('SendPrivateGroupMessageUsecase forwards every field', () async {
    when(() => transport.sendGroupMessage(
          groupId: any(named: 'groupId'),
          content: any(named: 'content'),
          authorPubkey: any(named: 'authorPubkey'),
          privkeyHex: any(named: 'privkeyHex'),
          mentionRefs: any(named: 'mentionRefs'),
          rootEventId: any(named: 'rootEventId'),
          replyToEventId: any(named: 'replyToEventId'),
          embeddedNoteJson: any(named: 'embeddedNoteJson'),
          attachments: any(named: 'attachments'),
        )).thenAnswer((_) async {});

    await SendPrivateGroupMessageUsecase(transport).execute(
      groupId: 'g1',
      content: 'hi',
      authorPubkey: 'author',
      privkeyHex: 'pk',
      replyToEventId: 'parent-1',
    );

    verify(() => transport.sendGroupMessage(
          groupId: 'g1',
          content: 'hi',
          authorPubkey: 'author',
          privkeyHex: 'pk',
          mentionRefs: const [],
          rootEventId: null,
          replyToEventId: 'parent-1',
          embeddedNoteJson: null,
          attachments: const [],
        )).called(1);
  });

  test('JoinPrivateGroupUsecase forwards every field', () async {
    when(() => transport.joinGroup(
          groupId: any(named: 'groupId'),
          authorPubkey: any(named: 'authorPubkey'),
          privkeyHex: any(named: 'privkeyHex'),
          relays: any(named: 'relays'),
        )).thenAnswer((_) async {});

    await JoinPrivateGroupUsecase(transport).execute(
      groupId: 'g1',
      authorPubkey: 'author',
      privkeyHex: 'pk',
      relays: const ['wss://relay.example'],
    );

    verify(() => transport.joinGroup(
          groupId: 'g1',
          authorPubkey: 'author',
          privkeyHex: 'pk',
          relays: const ['wss://relay.example'],
        )).called(1);
  });

  test('ApprovePrivateGroupJoinUsecase forwards every field', () async {
    when(() => transport.approveJoinRequest(
          groupId: any(named: 'groupId'),
          userKeyPackageB64: any(named: 'userKeyPackageB64'),
          adminPrivkeyHex: any(named: 'adminPrivkeyHex'),
        )).thenAnswer((_) async {});

    await ApprovePrivateGroupJoinUsecase(transport).execute(
      groupId: 'g1',
      userKeyPackageB64: 'b64',
      adminPrivkeyHex: 'pk',
    );

    verify(() => transport.approveJoinRequest(
          groupId: 'g1',
          userKeyPackageB64: 'b64',
          adminPrivkeyHex: 'pk',
        )).called(1);
  });

  test('LeavePrivateGroupUsecase forwards every field', () async {
    when(() => transport.leaveGroup(
          groupId: any(named: 'groupId'),
          authorPubkey: any(named: 'authorPubkey'),
          privkeyHex: any(named: 'privkeyHex'),
        )).thenAnswer((_) async {});

    await LeavePrivateGroupUsecase(transport).execute(
      groupId: 'g1',
      authorPubkey: 'author',
      privkeyHex: 'pk',
    );

    verify(() => transport.leaveGroup(
          groupId: 'g1',
          authorPubkey: 'author',
          privkeyHex: 'pk',
        )).called(1);
  });
}
