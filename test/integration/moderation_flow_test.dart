import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/feed_read_state_store.dart';
import 'package:uniun/data/models/blocked_user_model.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/repositories/blocked_user_repository_impl.dart';
import 'package:uniun/data/repositories/deleted_note_repository_impl.dart';
import 'package:uniun/data/repositories/event_queue_repository_impl.dart';
import 'package:uniun/data/repositories/feed_repository_impl.dart';
import 'package:uniun/data/repositories/note_attachments_enricher.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';
import 'package:uniun/data/repositories/note_resolver_repository_impl.dart';
import 'package:uniun/data/repositories/report_repository_impl.dart';
import 'package:uniun/data/repositories/source_label_repository_impl.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';

import '../_helpers/fixtures.dart';
import '../_helpers/isar_seeds.dart';
import '../_helpers/isar_test_harness.dart';
import '../_helpers/stub_followed_users.dart';
import '../_helpers/stub_user_repository.dart';

/// End-to-end moderation scenarios — the "user reports objectionable
/// content" path the App Store review hinges on. Wires the REAL Isar, the
/// real [ReportRepositoryImpl] (signs a real Kind-1984 event), the real
/// [EventQueueRepositoryImpl] (rows land in the actual outbound queue and
/// are serialized through the canonical NIP-56 tag shape), the real
/// [DeletedNoteRepositoryImpl] tombstone cascade, the real
/// [BlockedUserRepositoryImpl], and the real [FeedRepositoryImpl] to prove
/// the reported content actually disappears from the reporter's feed.
/// Only the identity ([StubUserRepository]) and follow list are stubbed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late ReportRepositoryImpl reports;
  late DeletedNoteRepositoryImpl deletions;
  late BlockedUserRepositoryImpl blocks;
  late FeedRepositoryImpl feed;
  late NoteRelationRepositoryImpl relations;

  setUp(() async {
    isar = await openTestIsar();
    SharedPreferences.setMockInitialValues({});

    final user = StubUserRepository()
      ..keys = (privkeyHex: kTestPrivHex, pubkeyHex: kSelfPub);
    reports = ReportRepositoryImpl(
      isar: isar,
      eventQueueRepository: EventQueueRepositoryImpl(isar: isar),
      userRepository: user,
    );
    deletions = DeletedNoteRepositoryImpl(isar: isar);
    blocks = BlockedUserRepositoryImpl(
      isar: isar,
      signer: MeshEventSigner(StubUserRepository()..keys = null),
    );
    relations = NoteRelationRepositoryImpl(isar: isar);
    feed = FeedRepositoryImpl(
      isar: isar,
      relations: relations,
      sourceLabels: SourceLabelRepositoryImpl(isar: isar),
      follows: StubFollowedUsers()..pubkeys = [kAlicePub, kEvePub],
      users: user,
      feedReadState: FeedReadStateStore(await SharedPreferences.getInstance()),
      resolver: NoteResolverRepositoryImpl(
        isar: isar,
        relations: relations,
        attachments: NoteAttachmentsEnricher(isar: isar),
      ),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  List<String> feedIds(dynamic either) =>
      (either.getOrElse(() => const <NoteEntity>[]) as List<NoteEntity>)
          .map((n) => n.id)
          .toList();

  test(
      'SCENARIO: offensive note arrives → user reports it with tombstone → '
      'a signed Kind-1984 hits the outbound queue in NIP-56 wire shape AND '
      'the note vanishes from both feed buckets', () async {
    // 1. An offensive note is in the feed (unread, from a followed user).
    await seedNoteRow(isar, kSampleEventIdHex, authorPubkey: kEvePub);
    await seedUnreadRow(isar, kSampleEventIdHex, authorPubkey: kEvePub);
    expect(feedIds(await feed.getUnread(limit: 10, excludeIds: {})),
        [kSampleEventIdHex]);

    // 2. The user files the report (ReportSheetCubit effect #1)…
    final reported = await reports.reportNote(
      targetEventId: kSampleEventIdHex,
      targetPubkey: kSampleTargetPubkeyHex,
      type: ReportType.nudity,
      content: 'graphic content',
    );
    expect(reported.isRight(), isTrue);

    // …and tombstones it locally (effect #2).
    expect((await deletions.deleteNote(kSampleEventIdHex)).isRight(), isTrue);

    // 3. The outbound queue holds a REAL signed event that re-serializes to
    //    the exact NIP-56 shape the relay verifies against.
    final row = (await isar.eventQueueModels.where().findAll()).single;
    expect(row.kind, kReportKind);
    final wire = jsonDecode(row.toSerializedRelayMessage()) as List<dynamic>;
    final ev = wire[1] as Map<String, dynamic>;
    expect(ev['tags'], [
      ['e', kSampleEventIdHex, '', 'nudity'],
      ['p', kSampleTargetPubkeyHex, 'nudity'],
    ]);
    expect(ev['content'], 'graphic content');
    expect(ev['sig'], matches(r'^[0-9a-f]{120,128}$'));

    // 4. Reporter's feed is clean — both phases, plus the tombstone persists.
    expect(feedIds(await feed.getUnread(limit: 10, excludeIds: {})), isEmpty);
    expect(feedIds(await feed.getSeen(limit: 10)), isEmpty);
    expect(await isar.noteModels.count(), 0);
    expect(await isar.deletedNoteModels.count(), 1);
  });

  test(
      'SCENARIO: report + "Also block this user" → author lands on the '
      'block list; repeat block is a no-op', () async {
    await seedNoteRow(isar, kSampleEventIdHex, authorPubkey: kEvePub);

    await reports.reportNote(
      targetEventId: kSampleEventIdHex,
      targetPubkey: kSampleTargetPubkeyHex,
      type: ReportType.spam,
    );
    await deletions.deleteNote(kSampleEventIdHex);
    expect((await blocks.blockUser(kSampleTargetPubkeyHex)).isRight(),
        isTrue);
    // Second submission with the checkbox on must not duplicate the row.
    expect((await blocks.blockUser(kSampleTargetPubkeyHex)).isRight(),
        isTrue);

    final blocked = (await blocks.getAll()).getOrElse(() => const []);
    expect(blocked.map((b) => b.pubkeyHex), [kSampleTargetPubkeyHex]);
    expect(await isar.blockedUserModels.count(), 1);
  });

  test(
      'SCENARIO: reporting a thread root cleans its relation edges so the '
      'surviving reply\'s counts stay consistent', () async {
    await seedNoteRow(isar, 'root-note', authorPubkey: kEvePub);
    await seedNoteRow(isar, 'the-reply',
        authorPubkey: kAlicePub,
        rootEventId: 'root-note',
        replyToEventId: 'root-note');
    await seedRelationEdge(isar, 'root-note', 'the-reply');
    expect(await relations.referenceCount('the-reply'), 1);

    await reports.reportNote(
      targetEventId: 'root-note',
      targetPubkey: kSampleTargetPubkeyHex,
      type: ReportType.illegal,
    );
    await deletions.deleteNote('root-note');

    // Edge table no longer points at the purged root.
    expect(await relations.referenceCount('the-reply'), 0);
    expect(await isar.noteRelationModels.count(), 0);
    // The reply row itself survives (only the reported note is tombstoned).
    expect(await isar.noteModels.count(), 1);
  });

  test(
      'SCENARIO: profile-only report (no note target) → p-tag-only event, '
      'no local tombstone side effects', () async {
    await seedNoteRow(isar, 'innocent-note', authorPubkey: kEvePub);

    final r = await reports.reportUser(
      targetPubkey: kSampleTargetPubkeyHex,
      type: ReportType.impersonation,
      content: 'fake account',
    );
    expect(r.isRight(), isTrue);

    final row = (await isar.eventQueueModels.where().findAll()).single;
    final ev = (jsonDecode(row.toSerializedRelayMessage())
        as List<dynamic>)[1] as Map<String, dynamic>;
    expect(ev['tags'], [
      ['p', kSampleTargetPubkeyHex, 'impersonation'],
    ]);
    // No note was harmed: profile reports never tombstone content.
    expect(await isar.noteModels.count(), 1);
    expect(await isar.deletedNoteModels.count(), 0);
  });

  test(
      'SCENARIO: logged-out user cannot report — nothing enqueued, feed '
      'untouched', () async {
    await seedNoteRow(isar, kSampleEventIdHex, authorPubkey: kEvePub);
    final loggedOut = ReportRepositoryImpl(
      isar: isar,
      eventQueueRepository: EventQueueRepositoryImpl(isar: isar),
      userRepository: StubUserRepository()..keys = null,
    );

    final r = await loggedOut.reportNote(
      targetEventId: kSampleEventIdHex,
      targetPubkey: kSampleTargetPubkeyHex,
      type: ReportType.spam,
    );
    expect(r.isLeft(), isTrue);
    expect(await isar.eventQueueModels.count(), 0);
    expect(await isar.noteModels.count(), 1);
  });
}
