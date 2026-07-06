import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/repositories/event_queue_repository_impl.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';

import '../../_helpers/fixtures.dart';
import '../../_helpers/isar_seeds.dart';
import '../../_helpers/isar_test_harness.dart';

/// Covers: EventQueueRepositoryImpl enqueue (persistence, idempotency, imeta
/// mapping) + the canonical tag-order contract of `toSerializedRelayMessage`
/// for every kind path (1 / 42 / 9023 / 31234 / 10063 / 1984 / share embed).
/// Wrong order = re-serialized hash mismatch = relay rejects the signature.
void main() {
  // ── Serializer helpers ──────────────────────────────────────────────────────

  List<List<String>> tagsOf(EventQueueModel row) {
    final outer = jsonDecode(row.toSerializedRelayMessage()) as List<dynamic>;
    final payload = outer[1] as Map<String, dynamic>;
    return (payload['tags'] as List<dynamic>)
        .map((t) => (t as List<dynamic>).cast<String>())
        .toList();
  }

  Map<String, dynamic> eventOf(EventQueueModel row) {
    final outer = jsonDecode(row.toSerializedRelayMessage()) as List<dynamic>;
    return outer[1] as Map<String, dynamic>;
  }

  // ── Wire envelope ───────────────────────────────────────────────────────────

  group('wire envelope', () {
    test('serializes as ["EVENT", {id,pubkey,created_at,kind,tags,content,sig}]',
        () {
      final row = eventQueueRow(
        'ev-1',
        authorPubkey: kSampleTargetPubkeyHex,
        sig: 'the-sig',
        content: 'hello',
        created: DateTime.utc(2026, 6, 1, 10, 30),
      );
      final outer =
          jsonDecode(row.toSerializedRelayMessage()) as List<dynamic>;
      expect(outer[0], 'EVENT');
      final ev = outer[1] as Map<String, dynamic>;
      expect(ev['id'], 'ev-1');
      expect(ev['pubkey'], kSampleTargetPubkeyHex);
      expect(ev['kind'], kNoteKind);
      expect(ev['content'], 'hello');
      expect(ev['sig'], 'the-sig');
      expect(ev.keys.toList(),
          ['id', 'pubkey', 'created_at', 'kind', 'tags', 'content', 'sig']);
    });

    test('created_at is whole seconds (millis truncated, not rounded)', () {
      final row = eventQueueRow(
        'ev-1',
        created: DateTime.utc(2026, 6, 1).add(const Duration(
            seconds: 5, milliseconds: 999)),
      );
      final base =
          DateTime.utc(2026, 6, 1).millisecondsSinceEpoch ~/ 1000;
      expect(eventOf(row)['created_at'], base + 5);
    });

    test('unicode + emoji + RTL content survives the JSON round-trip', () {
      final row = eventQueueRow('ev-1',
          content: '${Content.unicode} ${Content.emoji} ${Content.rtl}');
      expect(eventOf(row)['content'],
          '${Content.unicode} ${Content.emoji} ${Content.rtl}');
    });
  });

  // ── Canonical tag order — the everything-set master test ───────────────────

  group('canonical tag order', () {
    test(
        'all slots populated → e root, e reply, e mention…, p…, t…, h, d, k, '
        'embeddedNoteJson, expiration, server…, imeta…', () {
      final row = eventQueueRow(
        'ev-1',
        eTagRefs: ['root-id', 'parent-id', 'mention-1', 'mention-2'],
        rootEventId: 'root-id',
        replyToEventId: 'parent-id',
        pTagRefs: [kBobPub, kCarolPub],
        tTags: ['tag1', 'tag2'],
        hTag: 'group-1',
        dTag: 'draft-1',
        quoteKind: 1,
        embeddedNoteJson: '{"id":"snap"}',
        expirationSec: 1750000000,
        serverTags: ['https://s1', 'https://s2'],
        imeta: [
          mediaAttachmentRow(sha256: 'sha-a', url: 'https://s/a.jpg'),
        ],
      );
      expect(tagsOf(row), [
        ['e', 'root-id', '', 'root'],
        ['e', 'parent-id', '', 'reply'],
        ['e', 'mention-1', '', 'mention'],
        ['e', 'mention-2', '', 'mention'],
        ['p', kBobPub],
        ['p', kCarolPub],
        ['t', 'tag1'],
        ['t', 'tag2'],
        ['h', 'group-1'],
        ['d', 'draft-1'],
        ['k', '1'],
        [EmbeddedNoteCodec.tagName, '{"id":"snap"}'],
        ['expiration', '1750000000'],
        ['server', 'https://s1'],
        ['server', 'https://s2'],
        ['imeta', 'url https://s/a.jpg', 'm image/jpeg', 'x sha-a', 'size 42'],
      ]);
    });

    test('root/reply ids in eTagRefs are deduped from the mention run', () {
      final row = eventQueueRow(
        'ev-1',
        eTagRefs: ['root-id', 'parent-id', 'mention-1'],
        rootEventId: 'root-id',
        replyToEventId: 'parent-id',
      );
      final eTags = tagsOf(row).where((t) => t.first == 'e').toList();
      expect(eTags, [
        ['e', 'root-id', '', 'root'],
        ['e', 'parent-id', '', 'reply'],
        ['e', 'mention-1', '', 'mention'],
      ]);
    });

    test('root marker without reply marker (top-of-thread reply)', () {
      final row = eventQueueRow(
        'ev-1',
        eTagRefs: ['root-id'],
        rootEventId: 'root-id',
      );
      expect(tagsOf(row), [
        ['e', 'root-id', '', 'root'],
      ]);
    });

    test('no tags at all → empty tags array', () {
      expect(tagsOf(eventQueueRow('ev-1')), isEmpty);
    });
  });

  // ── Per-kind paths ──────────────────────────────────────────────────────────

  group('per-kind tag shapes', () {
    test('Kind 1 note with media → e/p/t then imeta rows last', () {
      final row = eventQueueRow(
        'ev-1',
        kind: kNoteKind,
        eTagRefs: ['mention-1'],
        pTagRefs: [kBobPub],
        tTags: ['topic'],
        imeta: [
          mediaAttachmentRow(sha256: 'sha-a'),
          mediaAttachmentRow(sha256: 'sha-b', mime: 'video/mp4'),
        ],
      );
      final tags = tagsOf(row);
      expect(tags.map((t) => t.first).toList(),
          ['e', 'p', 't', 'imeta', 'imeta']);
      expect(tags[3], contains('x sha-a'));
      expect(tags[4], contains('m video/mp4'));
    });

    test('Kind 42 group message → root marker to the Kind-40 id + imeta', () {
      final row = eventQueueRow(
        'ev-1',
        kind: kGroupMessageKind,
        eTagRefs: ['kind40-id'],
        rootEventId: 'kind40-id',
        imeta: [mediaAttachmentRow(sha256: 'sha-a')],
      );
      final tags = tagsOf(row);
      expect(tags.first, ['e', 'kind40-id', '', 'root']);
      expect(tags.last.first, 'imeta');
      expect(eventOf(row)['kind'], kGroupMessageKind);
    });

    test('Kind 9023 private group → h tag after p/t, before everything else',
        () {
      final row = eventQueueRow(
        'ev-1',
        kind: kPrivateGroupKind,
        pTagRefs: [kBobPub],
        tTags: ['topic'],
        hTag: 'group-9',
      );
      expect(tagsOf(row), [
        ['p', kBobPub],
        ['t', 'topic'],
        ['h', 'group-9'],
      ]);
    });

    test('Kind 31234 draft → d, k, expiration in canonical slots', () {
      final row = eventQueueRow(
        'ev-1',
        kind: kDraftWrapKind,
        dTag: 'draft-abc',
        quoteKind: 1,
        expirationSec: 1234567890,
      );
      expect(tagsOf(row), [
        ['d', 'draft-abc'],
        ['k', '1'],
        ['expiration', '1234567890'],
      ]);
    });

    test('Kind 10063 server list → one server tag per url, in order', () {
      final row = eventQueueRow(
        'ev-1',
        kind: 10063,
        serverTags: ['https://blossom.a', 'https://blossom.b'],
      );
      expect(tagsOf(row), [
        ['server', 'https://blossom.a'],
        ['server', 'https://blossom.b'],
      ]);
    });

    test('share note → embeddedNoteJson tag between k-slot and expiration',
        () {
      final row = eventQueueRow(
        'ev-1',
        eTagRefs: ['mention-1'],
        embeddedNoteJson: '{"id":"original","sig":"s"}',
      );
      expect(tagsOf(row), [
        ['e', 'mention-1', '', 'mention'],
        [EmbeddedNoteCodec.tagName, '{"id":"original","sig":"s"}'],
      ]);
    });

    test('Kind 1984 report → reportType reshapes e/p rows, NIP-10 suppressed',
        () {
      final row = eventQueueRow(
        'ev-1',
        kind: kReportKind,
        eTagRefs: [kSampleEventIdHex],
        pTagRefs: [kSampleTargetPubkeyHex],
        rootEventId: kSampleEventIdHex,
        reportType: 'spam',
      );
      expect(tagsOf(row), [
        ['e', kSampleEventIdHex, '', 'spam'],
        ['p', kSampleTargetPubkeyHex, 'spam'],
      ]);
    });
  });

  // ── imeta variants ──────────────────────────────────────────────────────────

  group('imeta tag entries', () {
    test('full attachment → url, m, x, size, dim, blurhash, name — in order',
        () {
      final row = eventQueueRow('ev-1', imeta: [
        mediaAttachmentRow(
          sha256: 'sha-full',
          mime: 'image/png',
          sizeBytes: 999,
          url: 'https://s/full.png',
          width: 640,
          height: 480,
          blurhash: 'LKO2',
          filename: 'full.png',
        ),
      ]);
      expect(tagsOf(row).single, [
        'imeta',
        'url https://s/full.png',
        'm image/png',
        'x sha-full',
        'size 999',
        'dim 640x480',
        'blurhash LKO2',
        'name full.png',
      ]);
    });

    test('optional entries dropped: no url / size 0 / partial dim / empty name',
        () {
      final row = eventQueueRow('ev-1', imeta: [
        mediaAttachmentRow(
          sha256: 'sha-min',
          sizeBytes: 0,
          url: null,
          width: 640, // height missing → no dim entry
          filename: '',
        ),
      ]);
      expect(tagsOf(row).single, [
        'imeta',
        'm image/jpeg',
        'x sha-min',
      ]);
    });
  });

  // ── Repository (real Isar) ──────────────────────────────────────────────────

  group('EventQueueRepositoryImpl.enqueueSignedEvent', () {
    late Isar isar;
    late EventQueueRepositoryImpl repo;

    setUp(() async {
      isar = await openTestIsar();
      repo = EventQueueRepositoryImpl(isar: isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
    });

    Future<Either<Failure, int>> enqueue({
      String eventId = 'ev-1',
      int kind = kNoteKind,
      List<String> eTagRefs = const [],
      String? rootEventId,
      String? replyToEventId,
      List<String> pTagRefs = const [],
      List<String> tTags = const [],
      String content = 'x',
      String? embeddedNoteJson,
      int? quoteKind,
      String? hTag,
      String? dTag,
      int? expirationSec,
      List<String> serverTags = const [],
      List<MediaBlobEntity> imeta = const [],
      String? reportType,
    }) =>
        repo.enqueueSignedEvent(
          eventId: eventId,
          authorPubkey: kAlicePub,
          sig: 'sig',
          kind: kind,
          eTagRefs: eTagRefs,
          rootEventId: rootEventId,
          replyToEventId: replyToEventId,
          pTagRefs: pTagRefs,
          tTags: tTags,
          content: content,
          created: tNow,
          embeddedNoteJson: embeddedNoteJson,
          quoteKind: quoteKind,
          hTag: hTag,
          dTag: dTag,
          expirationSec: expirationSec,
          serverTags: serverTags,
          imeta: imeta,
          reportType: reportType,
        );

    test('persists a row with every field mapped', () async {
      final result = await enqueue(
        eTagRefs: ['root-id', 'mention-1'],
        rootEventId: 'root-id',
        pTagRefs: [kBobPub],
        tTags: ['topic'],
        content: 'hello',
        embeddedNoteJson: '{"id":"snap"}',
        quoteKind: 1,
        hTag: 'h-1',
        dTag: 'd-1',
        expirationSec: 42,
        serverTags: ['https://s'],
        reportType: 'spam',
      );
      expect(result.isRight(), isTrue);

      final row = (await isar.eventQueueModels.where().findAll()).single;
      expect(row.eventId, 'ev-1');
      expect(row.authorPubkey, kAlicePub);
      expect(row.eTagRefs, ['root-id', 'mention-1']);
      expect(row.rootEventId, 'root-id');
      expect(row.replyToEventId, isNull);
      expect(row.pTagRefs, [kBobPub]);
      expect(row.tTags, ['topic']);
      expect(row.content, 'hello');
      expect(row.embeddedNoteJson, '{"id":"snap"}');
      expect(row.quoteKind, 1);
      expect(row.hTag, 'h-1');
      expect(row.dTag, 'd-1');
      expect(row.expirationSec, 42);
      expect(row.serverTags, ['https://s']);
      expect(row.reportType, 'spam');
      expect(row.sentCount, 0);
    });

    test('imeta maps MediaBlobEntity → MediaAttachment (first serverUrl wins)',
        () async {
      await enqueue(imeta: [
        aMediaBlob(
          sha256: 'sha-1',
          mime: 'image/png',
          sizeBytes: 7,
          dim: const MediaDim(width: 10, height: 20),
          blurhash: 'bh',
          filename: 'f.png',
          serverUrls: ['https://first', 'https://second'],
        ),
      ]);
      final a = (await isar.eventQueueModels.where().findAll())
          .single
          .imeta
          .single;
      expect(a.sha256, 'sha-1');
      expect(a.mime, 'image/png');
      expect(a.sizeBytes, 7);
      expect(a.url, 'https://first');
      expect(a.width, 10);
      expect(a.height, 20);
      expect(a.blurhash, 'bh');
      expect(a.filename, 'f.png');
    });

    test('imeta with no serverUrls → null url', () async {
      await enqueue(imeta: [aMediaBlob(serverUrls: const [])]);
      final a = (await isar.eventQueueModels.where().findAll())
          .single
          .imeta
          .single;
      expect(a.url, isNull);
    });

    test('idempotent: second enqueue of same eventId returns existing row id',
        () async {
      final first = await enqueue(content: 'original');
      final second = await enqueue(content: 'changed');
      expect(first.isRight(), isTrue);
      expect(second.isRight(), isTrue);
      expect(second.getOrElse(() => -1), first.getOrElse(() => -2));

      final rows = await isar.eventQueueModels.where().findAll();
      expect(rows, hasLength(1));
      // Short-circuit means the original content is untouched.
      expect(rows.single.content, 'original');
    });

    test('distinct eventIds get monotonically increasing queue ids', () async {
      final a = await enqueue(eventId: 'ev-a');
      final b = await enqueue(eventId: 'ev-b');
      final idA = a.getOrElse(() => -1);
      final idB = b.getOrElse(() => -1);
      expect(idB, greaterThan(idA));
    });

    test('enqueued row round-trips through the canonical serializer',
        () async {
      await enqueue(
        eTagRefs: ['root-id', 'parent-id'],
        rootEventId: 'root-id',
        replyToEventId: 'parent-id',
        pTagRefs: [kBobPub],
      );
      final row = (await isar.eventQueueModels.where().findAll()).single;
      final tags = tagsOf(row);
      expect(tags, [
        ['e', 'root-id', '', 'root'],
        ['e', 'parent-id', '', 'reply'],
        ['p', kBobPub],
      ]);
    });

    test('10 concurrent enqueues of distinct events all persist', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++) enqueue(eventId: 'ev-$i'),
      ]);
      expect(await isar.eventQueueModels.count(), 10);
    });
  });
}
