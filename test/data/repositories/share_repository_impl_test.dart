import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/data/repositories/share_repository_impl.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/repositories/note_resolver_repository.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

import '../../_helpers/fixtures.dart';

/// Dispatcher tests for [ShareRepositoryImpl]. Every destination path is a
/// pass-through to an existing publish use case, so the test doubles record
/// the exact input passed to each of them and we assert on the captured
/// [ShareNoteInput] → downstream input translation.
class _MResolver extends Mock implements NoteResolverRepository {}

class _MGetKeys extends Mock implements GetActiveUserKeysUseCase {}

class _MPublishFeed extends Mock implements PublishMediaNoteUseCase {}

class _MPublishGroup extends Mock implements CreateGroupMessageUseCase {}

class _MPublishDm extends Mock implements SendDmUseCase {}

class _MPublishPrivateGroup extends Mock implements SendPrivateGroupMessageUsecase {}

void main() {
  late _MResolver resolver;
  late _MGetKeys getKeys;
  late _MPublishFeed publishFeed;
  late _MPublishGroup publishGroup;
  late _MPublishDm publishDm;
  late _MPublishPrivateGroup publishPrivateGroup;
  late ShareRepositoryImpl repo;

  const sourceId = 'source-1';
  final source = aNote(id: sourceId, content: 'original note');

  setUpAll(() {
    registerFallbackValue(
        PublishMediaNoteInput(note: source, attachments: const []));
    registerFallbackValue(const CreateGroupMessageInput(
      groupId: '',
      content: '',
      privateKey: '',
    ));
    registerFallbackValue(SendDmParams(otherPubkey: '', content: ''));
  });

  setUp(() {
    resolver = _MResolver();
    getKeys = _MGetKeys();
    publishFeed = _MPublishFeed();
    publishGroup = _MPublishGroup();
    publishDm = _MPublishDm();
    publishPrivateGroup = _MPublishPrivateGroup();

    when(() => resolver.resolveById(any())).thenAnswer((_) async => Right(source));
    when(() => getKeys()).thenAnswer((_) async => const Right(kSigningKeys));
    when(() => publishFeed(any()))
        .thenAnswer((_) async => Right(source));
    when(() => publishGroup(any()))
        .thenAnswer((_) async => Right(source));
    when(() => publishDm(any())).thenAnswer((_) async => const Right(unit));
    when(() => publishPrivateGroup.execute(
          groupId: any(named: 'groupId'),
          content: any(named: 'content'),
          authorPubkey: any(named: 'authorPubkey'),
          privkeyHex: any(named: 'privkeyHex'),
          mentionRefs: any(named: 'mentionRefs'),
          embeddedNoteJson: any(named: 'embeddedNoteJson'),
          attachments: any(named: 'attachments'),
        )).thenAnswer((_) async {});

    repo = ShareRepositoryImpl(
      resolver,
      getKeys,
      publishFeed,
      publishGroup,
      publishDm,
      publishPrivateGroup,
    );
  });

  // ── Common failure gates ──────────────────────────────────────────────────

  group('preconditions', () {
    test('resolver Left short-circuits — no publisher touched', () async {
      when(() => resolver.resolveById(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('not found')));

      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
      ));

      expect(r.isLeft(), isTrue);
      verifyNever(() => publishFeed(any()));
      verifyNever(() => publishGroup(any()));
      verifyNever(() => publishDm(any()));
    });

    test('missing active keys → Left, no publish', () async {
      when(() => getKeys()).thenAnswer(
          (_) async => const Left(Failure.errorFailure('no keys')));

      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
      ));

      expect(r.isLeft(), isTrue);
      verifyNever(() => publishFeed(any()));
    });

    test('resolver throw → caught → Left errorFailure', () async {
      when(() => resolver.resolveById(any()))
          .thenAnswer((_) async => throw StateError('boom'));

      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
      ));

      expect(r.isLeft(), isTrue);
    });
  });

  // ── ShareToFeed ───────────────────────────────────────────────────────────

  group('ShareToFeed', () {
    test('publishes a media note carrying the embed + refs + hashtags',
        () async {
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
        content: 'love this #nostr and #uniun',
        referenceIds: const ['ref-1', 'ref-2'],
      ));

      expect(r.isRight(), isTrue);
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      final note = captured.note;

      expect(note.content, 'love this #nostr and #uniun');
      expect(note.eTagRefs, ['ref-1', 'ref-2']);
      expect(note.tTags, containsAll(['nostr', 'uniun']));
      expect(note.embeddedNoteJson, isNotNull);
      expect(note.type, NoteType.text);
      expect(note.attachments, isEmpty);

      // Snapshot round-trips: decoded JSON matches the source note.
      final decoded =
          jsonDecode(note.embeddedNoteJson!) as Map<String, dynamic>;
      expect(decoded['id'], source.id);
      expect(decoded['content'], source.content);
    });

    test('image attachment upgrades NoteType to image', () async {
      final img = aMediaBlob(sha256: 'sha-img', mime: 'image/jpeg');
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
        attachments: [img],
      ));

      expect(r.isRight(), isTrue);
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      expect(captured.note.type, NoteType.image);
      expect(captured.attachments.single.sha256, 'sha-img');
    });

    test('non-image attachment (pdf) stays NoteType.text', () async {
      final pdf = aMediaBlob(sha256: 'sha-pdf', mime: 'application/pdf');
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
        attachments: [pdf],
      ));

      expect(r.isRight(), isTrue);
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      expect(captured.note.type, NoteType.text);
    });

    test('hashtag extraction: dedup + empty-tag filter', () async {
      await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
        content: '#tag #tag #other # #_underscore #123',
      ));
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      // "#tag" appears twice → dedup to 1; bare "#" filtered; underscore kept;
      // pure numbers kept (regex `\w+`).
      expect(captured.note.tTags.toSet(),
          {'tag', 'other', '_underscore', '123'});
    });

    test('unicode + emoji + RTL content survives to publisher', () async {
      final payload = '🚀 ${Content.unicode} ${Content.rtl}';
      await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
        content: payload,
      ));
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      expect(captured.note.content, payload);
    });

    test('content trim: leading + trailing whitespace stripped', () async {
      await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
        content: '   hello   \n',
      ));
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      expect(captured.note.content, 'hello');
    });

    test('publishFeed Left → repo Left', () async {
      when(() => publishFeed(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('relay boom')));
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
      ));
      expect(r.isLeft(), isTrue);
    });
  });

  // ── ShareToPublicGroup ────────────────────────────────────────────────────

  group('ShareToPublicGroup', () {
    test('delegates to CreateGroupMessageUseCase with embed + refs', () async {
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.publicGroup(groupId: 'g-1'),
        content: 'to the group',
        referenceIds: const ['r-1'],
      ));
      expect(r.isRight(), isTrue);
      final captured =
          verify(() => publishGroup(captureAny())).captured.single
              as CreateGroupMessageInput;
      expect(captured.groupId, 'g-1');
      expect(captured.content, 'to the group');
      expect(captured.mentionRefs, ['r-1']);
      expect(captured.embeddedNoteJson, isNotNull);
      expect(captured.privateKey, kTestPrivHex);
    });

    test('attachment carried through to group input', () async {
      final img = aMediaBlob(sha256: 'gsha', mime: 'image/png');
      await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.publicGroup(groupId: 'g-1'),
        attachments: [img],
      ));
      final captured =
          verify(() => publishGroup(captureAny())).captured.single
              as CreateGroupMessageInput;
      expect(captured.attachments.single.sha256, 'gsha');
    });

    test('publishGroup Left → repo Left', () async {
      when(() => publishGroup(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('group down')));
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.publicGroup(groupId: 'g-1'),
      ));
      expect(r.isLeft(), isTrue);
    });
  });

  // ── ShareToPrivateGroup ───────────────────────────────────────────────────

  group('ShareToPrivateGroup', () {
    test('delegates via .execute(...) with embed + refs + keys', () async {
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.privateGroup(groupId: 'pg-1'),
        content: 'hush',
        referenceIds: const ['pr-1'],
      ));
      expect(r.isRight(), isTrue);

      // Verify each named arg individually — the flat-list ordering of
      // mocktail's captureAny(named:) is not part of its documented contract.
      verify(() => publishPrivateGroup.execute(
            groupId: 'pg-1',
            content: 'hush',
            authorPubkey: kTestPubHex,
            privkeyHex: kTestPrivHex,
            mentionRefs: ['pr-1'],
            embeddedNoteJson: any(named: 'embeddedNoteJson', that: isA<String>()),
            attachments: [],
          )).called(1);
    });

    test('private group returns Right(unit) unconditionally (fire-and-forget)',
        () async {
      // .execute() returns Future<void> — the repo has no failure surface.
      when(() => publishPrivateGroup.execute(
            groupId: any(named: 'groupId'),
            content: any(named: 'content'),
            authorPubkey: any(named: 'authorPubkey'),
            privkeyHex: any(named: 'privkeyHex'),
            mentionRefs: any(named: 'mentionRefs'),
            embeddedNoteJson: any(named: 'embeddedNoteJson'),
            attachments: any(named: 'attachments'),
          )).thenAnswer((_) async {});
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.privateGroup(groupId: 'pg'),
      ));
      expect(r.isRight(), isTrue);
    });

    test('exception inside private group publish → caught → Left', () async {
      when(() => publishPrivateGroup.execute(
            groupId: any(named: 'groupId'),
            content: any(named: 'content'),
            authorPubkey: any(named: 'authorPubkey'),
            privkeyHex: any(named: 'privkeyHex'),
            mentionRefs: any(named: 'mentionRefs'),
            embeddedNoteJson: any(named: 'embeddedNoteJson'),
            attachments: any(named: 'attachments'),
          )).thenAnswer((_) async => throw StateError('mls boom'));
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.privateGroup(groupId: 'pg'),
      ));
      expect(r.isLeft(), isTrue);
    });
  });

  // ── ShareToDm ─────────────────────────────────────────────────────────────

  group('ShareToDm', () {
    test('delegates to SendDmUseCase with embed + refs + attachments',
        () async {
      final img = aMediaBlob(sha256: 'dm-img', mime: 'image/jpeg');
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.dm(otherPubkeyHex: 'peer'),
        content: 'psst',
        referenceIds: const ['dm-ref'],
        attachments: [img],
      ));
      expect(r.isRight(), isTrue);
      final captured =
          verify(() => publishDm(captureAny())).captured.single as SendDmParams;
      expect(captured.otherPubkey, 'peer');
      expect(captured.content, 'psst');
      expect(captured.mentionRefs, ['dm-ref']);
      expect(captured.embeddedNoteJson, isNotNull);
      expect(captured.attachments.single.sha256, 'dm-img');
      expect(captured.type, NoteType.image);
    });

    test('text-only DM stays NoteType.text', () async {
      await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.dm(otherPubkeyHex: 'peer'),
      ));
      final captured =
          verify(() => publishDm(captureAny())).captured.single as SendDmParams;
      expect(captured.type, NoteType.text);
    });

    test('publishDm Left → repo Left', () async {
      when(() => publishDm(any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('dm boom')));
      final r = await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.dm(otherPubkeyHex: 'peer'),
      ));
      expect(r.isLeft(), isTrue);
    });
  });

  // ── Double-nest guard ─────────────────────────────────────────────────────

  group('double-nest guard', () {
    test(
        'sharing a note that ITSELF quotes another → snapshot is the inner '
        'original, not the middle share', () async {
      final inner = aNote(id: 'inner', content: 'the actual thing');
      final middle = aNote(id: 'middle', content: 'my share', quotedNote: inner);
      when(() => resolver.resolveById(any()))
          .thenAnswer((_) async => Right(middle));

      await repo.shareNote(ShareNoteInput(
        sourceEventId: 'middle',
        destination: const ShareDestination.feed(),
      ));

      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      final decoded =
          jsonDecode(captured.note.embeddedNoteJson!) as Map<String, dynamic>;
      expect(decoded['id'], 'inner',
          reason: 'must snapshot inner, not middle');
      expect(decoded['content'], 'the actual thing');
    });

    test('sharing a plain note (no inner quote) snapshots the note itself',
        () async {
      final plain = aNote(id: 'plain', content: 'no quotes here');
      when(() => resolver.resolveById(any()))
          .thenAnswer((_) async => Right(plain));

      await repo.shareNote(ShareNoteInput(
        sourceEventId: 'plain',
        destination: const ShareDestination.feed(),
      ));

      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      final decoded =
          jsonDecode(captured.note.embeddedNoteJson!) as Map<String, dynamic>;
      expect(decoded['id'], 'plain');
    });
  });

  // ── Snapshot / tag shape ──────────────────────────────────────────────────

  group('EmbeddedNoteCodec integration', () {
    test('snapshot JSON captures all 7 canonical event fields', () async {
      await repo.shareNote(ShareNoteInput(
        sourceEventId: sourceId,
        destination: const ShareDestination.feed(),
      ));
      final captured =
          verify(() => publishFeed(captureAny())).captured.single
              as PublishMediaNoteInput;
      final decoded =
          jsonDecode(captured.note.embeddedNoteJson!) as Map<String, dynamic>;
      expect(decoded.keys, containsAll(
          ['id', 'pubkey', 'created_at', 'kind', 'tags', 'content', 'sig']));
    });

    test('EmbeddedNoteCodec.tag returns [tagName, json]', () {
      const snap = '{"id":"x"}';
      final t = EmbeddedNoteCodec.tag(snap);
      expect(t, hasLength(2));
      expect(t[1], snap);
    });
  });
}
