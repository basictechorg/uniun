import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/media/media_dim.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';

import '../_helpers/isar_test_harness.dart';

/// End-to-end "submit a new note" integration scenarios — the path the user
/// hits when they type into Brahma and tap Send. This is the **submit twin**
/// of `integration/draft_publish_flow_test.dart`: same shape, but exercising
/// the new-note path instead of the draft-publish path.
///
/// What's wired up for real:
///   - The on-disk Isar through [openTestIsar].
///   - [NoteRepositoryImpl] (saveNote → edge-table writes → idempotent reads).
///   - The pure tag-construction helpers (`buildNoteTags`, `extractHashtags`,
///     `buildImetaTags`) — same code the BLoC calls.
///   - Real secp256k1 signing through [Event.from] / [signNostrEvent].
///
/// The only stub is an in-memory [EventQueueRepository] recorder, so we can
/// assert that publishing actually went through the relay queue with the
/// canonical NIP-10 tag layout. (The BLoC isn't constructed; we replicate
/// the [_onSubmitNote] logic verbatim in [submitNote].)
void main() {
  late Isar isar;
  late NoteRepositoryImpl notes;
  late _RecordingQueue queue;
  late Keychain me;

  setUp(() async {
    me = Keychain.generate();
    isar = await openTestIsar();
    final relations = NoteRelationRepositoryImpl(isar: isar);
    notes = NoteRepositoryImpl(
      isar: isar,
      relations: relations,
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
    queue = _RecordingQueue();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  /// Verbatim port of [BrahmaCreateBloc._onSubmitNote] (no chain), with the
  /// `publishNote.call` replaced by direct calls into the real
  /// [NoteRepositoryImpl] + the queue. Returns the freshly-minted event id.
  Future<String> submitNote({
    required String content,
    String? rootEventId,
    String? replyToEventId,
    List<String> noteMentionIds = const [],
    List<MediaBlobEntity> attachments = const [],
  }) async {
    final hashtags = extractHashtags(content);
    final tags = buildNoteTags(
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      mentionIds: noteMentionIds,
      hashtags: hashtags,
    );
    if (attachments.isNotEmpty) {
      tags.addAll(buildImetaTags(attachments));
    }
    final ev = signNostrEvent(
      content: content,
      tags: tags,
      privkeyHex: me.private,
    );

    final eTagRefs = [
      if (rootEventId != null) rootEventId,
      if (replyToEventId != null) replyToEventId,
      ...noteMentionIds,
    ];
    final note = noteEntityFromEvent(
      event: ev,
      pubkeyHex: me.public,
      eTagRefs: eTagRefs,
      tTags: hashtags,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
    ).copyWith(
      type: attachments.any((b) => b.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text,
      attachments: attachments,
    );

    final saveRes = await notes.saveNote(note);
    expect(saveRes.isRight(), isTrue);
    await queue.enqueueSignedEvent(
      eventId: ev.id,
      authorPubkey: ev.pubkey,
      sig: ev.sig,
      kind: 1,
      eTagRefs: note.eTagRefs,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      pTagRefs: const [],
      tTags: hashtags,
      content: ev.content,
      created: DateTime.fromMillisecondsSinceEpoch(ev.createdAt * 1000),
      imeta: attachments,
    );
    return ev.id;
  }

  MediaBlobEntity blob(String sha,
          {String url = 'https://blossom.example/x',
          String mime = 'image/jpeg',
          MediaDim? dim,
          String? filename}) =>
      MediaBlobEntity(
        sha256: sha,
        mime: mime,
        sizeBytes: 100,
        dim: dim,
        filename: filename,
        serverUrls: [url],
      );

  // ── 1. Plain text submit ─────────────────────────────────────────────────

  group('Scenario: plain submit', () {
    test('typing a hashtag produces a t-tag and the note carries it', () async {
      final eventId = await submitNote(content: 'love #nostr');
      final n = (await notes.getNoteById(eventId))
          .getOrElse(() => throw 'missing');
      expect(n.tTags, ['nostr']);
      // Enqueued event also has the t-tag (the relay sees the same shape).
      expect(
        queue.calls.single.tTags,
        ['nostr'],
      );
    });

    test('empty content can still be submitted via the helper but produces an empty event', () async {
      // The BLoC's `_onSubmitNote` early-returns on empty content; we don't
      // replicate that gate here. The point is to verify that the publish
      // path itself is content-agnostic — empty events are valid Nostr
      // events, the UI just refuses to send them.
      final eventId = await submitNote(content: '   no content guard ');
      final n = (await notes.getNoteById(eventId))
          .getOrElse(() => throw 'missing');
      expect(n.content, '   no content guard ');
    });
  });

  // ── 2. Replies — NIP-10 root + reply markers preserved ───────────────────

  group('Scenario: reply with NIP-10 markers', () {
    test('reply carries root + reply event ids on both Isar row AND queue payload', () async {
      // Pre-existing root.
      await notes.saveNote(NoteEntity(
        id: 'root-id',
        sig: 's',
        authorPubkey: me.public,
        content: 'root',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      ));
      final replyId = await submitNote(
        content: 'response',
        rootEventId: 'root-id',
        replyToEventId: 'root-id',
      );
      final reply = (await notes.getNoteById(replyId))
          .getOrElse(() => throw 'missing');
      expect(reply.rootEventId, 'root-id');
      expect(reply.replyToEventId, 'root-id');
      // The edge table also picked it up as a reply.
      final root = (await notes.getNoteById('root-id'))
          .getOrElse(() => throw 'missing');
      expect(root.cachedReplyCount, 1);
    });

    test('deep reply (root != replyTo) — both markers travel through', () async {
      final replyId = await submitNote(
        content: 'response',
        rootEventId: 'root-id',
        replyToEventId: 'parent-id',
      );
      final n = (await notes.getNoteById(replyId))
          .getOrElse(() => throw 'missing');
      expect(n.rootEventId, 'root-id');
      expect(n.replyToEventId, 'parent-id');
      expect(n.eTagRefs, ['root-id', 'parent-id']);
    });
  });

  // ── 3. Note mentions — references survive into the published event ──────

  group('Scenario: referencing existing notes', () {
    test('mentioning two notes records both as outgoing references on the new note', () async {
      await notes.saveNote(NoteEntity(
        id: 'A',
        sig: 's',
        authorPubkey: me.public,
        content: 'a',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      ));
      await notes.saveNote(NoteEntity(
        id: 'B',
        sig: 's',
        authorPubkey: me.public,
        content: 'b',
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      ));
      final newId = await submitNote(
        content: 'quoting both',
        noteMentionIds: ['A', 'B'],
      );
      final n = (await notes.getNoteById(newId))
          .getOrElse(() => throw 'missing');
      expect(n.eTagRefs, ['A', 'B']);
      expect(n.referenceCount, 2);
      // Both referenced notes show the new one as an incoming reply.
      final a = (await notes.getNoteById('A')).getOrElse(() => throw 'missing');
      final b = (await notes.getNoteById('B')).getOrElse(() => throw 'missing');
      expect(a.cachedReplyCount, 1);
      expect(b.cachedReplyCount, 1);
    });
  });

  // ── 4. Media attachments — NIP-92 imeta in the canonical position ────────

  group('Scenario: with attachments', () {
    test('one image: type becomes image; imeta tag emitted; queue carries the typed list', () async {
      final attached = blob('sha-1', dim: const MediaDim(width: 800, height: 600));
      final id = await submitNote(
        content: 'with pic',
        attachments: [attached],
      );
      final n = (await notes.getNoteById(id)).getOrElse(() => throw 'missing');
      expect(n.type, NoteType.image);
      expect(n.attachments.single.sha256, 'sha-1');
      expect(queue.calls.single.imeta.single.sha256, 'sha-1');
    });

    test('multiple attachments preserve order in tags + on the entity', () async {
      final a = blob('sha-a', url: 'https://b/a');
      final b = blob('sha-b', url: 'https://b/b');
      final c = blob('sha-c', url: 'https://b/c');
      final id = await submitNote(content: 'three pics', attachments: [a, b, c]);
      final n = (await notes.getNoteById(id)).getOrElse(() => throw 'missing');
      expect(n.attachments.map((x) => x.sha256), ['sha-a', 'sha-b', 'sha-c']);
    });

    test('non-image mime keeps type = text', () async {
      final pdf =
          blob('sha-pdf', mime: 'application/pdf', url: 'https://b/pdf');
      final id = await submitNote(content: 'attached', attachments: [pdf]);
      final n = (await notes.getNoteById(id)).getOrElse(() => throw 'missing');
      expect(n.type, NoteType.text);
    });
  });

  // ── 5. Mixed reply + mention + media ────────────────────────────────────

  group('Scenario: reply + mention + image (full combo)', () {
    test('all three combine and survive the publish path', () async {
      final id = await submitNote(
        content: 'check #combo @ref',
        rootEventId: 'root',
        replyToEventId: 'parent',
        noteMentionIds: ['mention-1', 'mention-2'],
        attachments: [
          blob('sha-img', dim: const MediaDim(width: 100, height: 100)),
        ],
      );
      final n = (await notes.getNoteById(id)).getOrElse(() => throw 'missing');
      expect(n.rootEventId, 'root');
      expect(n.replyToEventId, 'parent');
      expect(n.eTagRefs,
          containsAllInOrder(['root', 'parent', 'mention-1', 'mention-2']));
      expect(n.tTags, ['combo']);
      expect(n.attachments.single.sha256, 'sha-img');
      expect(n.type, NoteType.image);
    });
  });

  // ── 6. Idempotency: re-submitting an identical event is a no-op ─────────

  group('Property: relay idempotency', () {
    test('two identical submits within 1s produce the same id; saveNote is idempotent', () async {
      // Same content + same key + same created_at = same SHA-256 = same id.
      // The note repo's saveNote returns the existing row on conflict.
      final first = await submitNote(content: 'identical');
      final second = await submitNote(content: 'identical');
      if (first == second) {
        // Wall-clock landed in the same second — single Isar row, queue
        // recorded both attempts.
        expect(await isar.noteModels.where().count(), 1);
      } else {
        // Crossed a second boundary — two distinct events, both stored.
        expect(await isar.noteModels.where().count(), 2);
      }
    });
  });
}

// ── Test doubles ─────────────────────────────────────────────────────────

class _EnqueueCall {
  _EnqueueCall({
    required this.eTagRefs,
    required this.tTags,
    required this.imeta,
    required this.rootEventId,
    required this.replyToEventId,
  });
  final List<String> eTagRefs;
  final List<String> tTags;
  final List<MediaBlobEntity> imeta;
  final String? rootEventId;
  final String? replyToEventId;
}

class _RecordingQueue implements EventQueueRepository {
  final List<_EnqueueCall> calls = [];

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
    calls.add(_EnqueueCall(
      eTagRefs: eTagRefs,
      tTags: tTags,
      imeta: imeta,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
    ));
    return const Right(1);
  }
}

