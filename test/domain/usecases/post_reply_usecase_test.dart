import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/post_reply_usecase.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';

import '../../_helpers/fixtures.dart';

class _MockPublishNote extends Mock implements PublishNoteUseCase {}

class _MockPublishMediaNote extends Mock implements PublishMediaNoteUseCase {}

class _MockCreateGroupMessage extends Mock
    implements CreateGroupMessageUseCase {}

class _MockSendPrivate extends Mock implements SendPrivateGroupMessageUsecase {}

class _MockSendDm extends Mock implements SendDmUseCase {}

class _MockGetActiveUserKeys extends Mock
    implements GetActiveUserKeysUseCase {}

class _MockEmbedAndStore extends Mock implements EmbedAndStoreNoteUseCase {}

const _validPrivkeyHex =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  late _MockPublishNote publishNote;
  late _MockPublishMediaNote publishMediaNote;
  late _MockCreateGroupMessage createGroupMessage;
  late _MockSendPrivate sendPrivate;
  late _MockSendDm sendDm;
  late _MockGetActiveUserKeys getKeys;
  late _MockEmbedAndStore embedAndStore;
  late PostReplyUseCase useCase;

  setUpAll(() {
    registerFallbackValue(aNote());
    registerFallbackValue(const CreateGroupMessageInput(
      groupId: '',
      content: '',
      privateKey: '',
    ));
    registerFallbackValue(SendDmParams(otherPubkey: '', content: ''));
    registerFallbackValue(('', ''));
    registerFallbackValue(PublishMediaNoteInput(note: aNote(), attachments: const []));
  });

  setUp(() {
    publishNote = _MockPublishNote();
    publishMediaNote = _MockPublishMediaNote();
    createGroupMessage = _MockCreateGroupMessage();
    sendPrivate = _MockSendPrivate();
    sendDm = _MockSendDm();
    getKeys = _MockGetActiveUserKeys();
    embedAndStore = _MockEmbedAndStore();
    useCase = PostReplyUseCase(
      publishNote,
      publishMediaNote,
      createGroupMessage,
      sendPrivate,
      sendDm,
      getKeys,
      embedAndStore,
    );

    when(() => getKeys.call()).thenAnswer((_) async => const Right(
          UserSigningKeys(privkeyHex: _validPrivkeyHex, pubkeyHex: 'self-pub'),
        ));
    when(() => embedAndStore.call(any())).thenAnswer((_) async {});
  });

  test('a key-fetch failure short-circuits before dispatching anywhere',
      () async {
    const failure = Failure.errorFailure('no active user');
    when(() => getKeys.call()).thenAnswer((_) async => const Left(failure));

    final result = await useCase.call(PostReplyParams(root: aNote(), content: 'hi'));

    expect(result, const Left<Failure, Unit>(failure));
    verifyZeroInteractions(publishNote);
  });

  group('feed replies', () {
    test('signs a real kind-1 reply and publishes it, then fires knowledge '
        'extraction', () async {
      final root = aNote(id: 'root-1');
      when(() => publishNote.call(any()))
          .thenAnswer((i) async => Right(i.positionalArguments.first as NoteEntity));

      final result = await useCase.call(PostReplyParams(root: root, content: 'a reply'));

      expect(result, const Right<Failure, Unit>(unit));
      final published =
          verify(() => publishNote.call(captureAny())).captured.single as NoteEntity;
      expect(published.replyToEventId, 'root-1');
      expect(published.rootEventId, 'root-1');
      expect(published.content, 'a reply');
      await Future<void>.delayed(Duration.zero);
      verify(() => embedAndStore.call(any())).called(1);
    });

    test('a reply to a REPLY threads under the original root, not the '
        'immediate parent', () async {
      final root = aNote(id: 'root-1');
      final reply = aReply(parent: root, id: 'reply-1');
      when(() => publishNote.call(any()))
          .thenAnswer((i) async => Right(i.positionalArguments.first as NoteEntity));

      await useCase.call(PostReplyParams(root: reply, content: 'a nested reply'));

      final published =
          verify(() => publishNote.call(captureAny())).captured.single as NoteEntity;
      expect(published.rootEventId, 'root-1');
      expect(published.replyToEventId, 'reply-1');
    });

    test('attachments route through PublishMediaNoteUseCase instead of '
        'PublishNoteUseCase', () async {
      final root = aNote(id: 'root-1');
      when(() => publishMediaNote.call(any()))
          .thenAnswer((i) async => Right((i.positionalArguments.first as PublishMediaNoteInput).note));

      final result = await useCase.call(PostReplyParams(
        root: root,
        content: 'with an image',
        attachments: [aMediaBlob()],
      ));

      expect(result, const Right<Failure, Unit>(unit));
      verifyZeroInteractions(publishNote);
      verify(() => publishMediaNote.call(any())).called(1);
    });

    test('a signing failure (malformed privkey) surfaces as Left', () async {
      when(() => getKeys.call()).thenAnswer((_) async => const Right(
            UserSigningKeys(privkeyHex: 'not-a-valid-key', pubkeyHex: 'self-pub'),
          ));

      final result = await useCase.call(PostReplyParams(root: aNote(), content: 'hi'));

      expect(result.isLeft(), isTrue);
      verifyZeroInteractions(publishNote);
    });

    test('a publish failure surfaces as Left, no embed/extraction fires',
        () async {
      const failure = Failure.errorFailure('isar write failed');
      when(() => publishNote.call(any())).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call(PostReplyParams(root: aNote(), content: 'hi'));

      expect(result, const Left<Failure, Unit>(failure));
      verifyZeroInteractions(embedAndStore);
    });
  });

  group('group replies', () {
    test('routes to CreateGroupMessageUseCase with the group id + reply '
        'pointer', () async {
      final root = aGroupMessage(groupId: 'g1', id: 'gm-1');
      when(() => createGroupMessage.call(any()))
          .thenAnswer((_) async => Right(aGroupMessage(groupId: 'g1', id: 'gm-2')));

      final result = await useCase.call(PostReplyParams(root: root, content: 'group reply'));

      expect(result, const Right<Failure, Unit>(unit));
      final input =
          verify(() => createGroupMessage.call(captureAny())).captured.single
              as CreateGroupMessageInput;
      expect(input.groupId, 'g1');
      expect(input.replyToEventId, 'gm-1');
      expect(input.content, 'group reply');
    });

    test('a group-message failure surfaces as Left', () async {
      final root = aGroupMessage(groupId: 'g1', id: 'gm-1');
      const failure = Failure.errorFailure('relay down');
      when(() => createGroupMessage.call(any())).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call(PostReplyParams(root: root, content: 'hi'));

      expect(result, const Left<Failure, Unit>(failure));
    });
  });

  group('private-group replies', () {
    test('routes to SendPrivateGroupMessageUsecase with the private group '
        'id + thread pointers', () async {
      final root = aPrivateGroupMessage(groupId: 'pg1', id: 'pgm-1');
      when(() => sendPrivate.execute(
            groupId: any(named: 'groupId'),
            content: any(named: 'content'),
            authorPubkey: any(named: 'authorPubkey'),
            privkeyHex: any(named: 'privkeyHex'),
            mentionRefs: any(named: 'mentionRefs'),
            rootEventId: any(named: 'rootEventId'),
            replyToEventId: any(named: 'replyToEventId'),
            attachments: any(named: 'attachments'),
          )).thenAnswer((_) async {});

      final result = await useCase.call(PostReplyParams(root: root, content: 'secret reply'));

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => sendPrivate.execute(
            groupId: 'pg1',
            content: 'secret reply',
            authorPubkey: 'self-pub',
            privkeyHex: _validPrivkeyHex,
            mentionRefs: const [],
            rootEventId: 'pgm-1',
            replyToEventId: 'pgm-1',
            attachments: const [],
          )).called(1);
    });
  });

  group('DM replies', () {
    test('replies to a DM authored by the peer using their own pubkey',
        () async {
      final root = aDmText(conversationId: 1, id: 'dm-1', authorPubkey: 'peer-pub');
      when(() => sendDm.call(any())).thenAnswer((_) async => const Right(unit));

      final result = await useCase.call(PostReplyParams(root: root, content: 'reply back'));

      expect(result, const Right<Failure, Unit>(unit));
      final params = verify(() => sendDm.call(captureAny())).captured.single as SendDmParams;
      expect(params.otherPubkey, 'peer-pub');
      expect(params.rootEventId, 'dm-1');
      expect(params.replyToEventId, 'dm-1');
    });

    test('replies to your OWN DM message using the receiver pubkey instead',
        () async {
      final root = aDmText(
        conversationId: 1,
        id: 'dm-1',
        authorPubkey: 'self-pub',
        recipient: 'peer-pub',
      );
      when(() => sendDm.call(any())).thenAnswer((_) async => const Right(unit));

      await useCase.call(PostReplyParams(root: root, content: 'follow-up'));

      final params = verify(() => sendDm.call(captureAny())).captured.single as SendDmParams;
      expect(params.otherPubkey, 'peer-pub');
    });

    test('an image attachment sets NoteType.image on the DM params',
        () async {
      final root = aDmText(conversationId: 1, id: 'dm-1', authorPubkey: 'peer-pub');
      when(() => sendDm.call(any())).thenAnswer((_) async => const Right(unit));

      await useCase.call(PostReplyParams(
        root: root,
        content: 'a photo',
        attachments: [aMediaBlob()],
      ));

      final params = verify(() => sendDm.call(captureAny())).captured.single as SendDmParams;
      expect(params.type.name, 'image');
    });
  });

  test('an explicit sourceOverride wins over the derived replyTransport',
      () async {
    // A feed-shaped note (no group/private/DM container fields) forced to
    // route as a group reply via sourceOverride.
    final root = aNote(id: 'n1');
    when(() => createGroupMessage.call(any()))
        .thenAnswer((_) async => Right(aGroupMessage(groupId: '', id: 'gm-1')));

    final result = await useCase.call(PostReplyParams(
      root: root,
      content: 'forced group route',
      sourceOverride: NoteSource.group,
    ));

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => createGroupMessage.call(any())).called(1);
    verifyZeroInteractions(publishNote);
  });
}
