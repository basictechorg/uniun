import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/report_model.dart';

import 'fixtures.dart';

/// Direct Isar seeding helpers for tests. Each writes inside its own
/// `writeTxn` and is safe to call ad-hoc from any test using `openTestIsar()`.
///
/// Extracted from duplicated helpers in `followed_note_repository_impl_test`
/// and `deleted_note_repository_impl_test`.
Future<void> seedNoteRow(
  Isar isar,
  String eventId, {
  String content = 'x',
  String authorPubkey = kAlicePub,
  int kind = kNoteKind,
  DateTime? created,
}) async {
  await isar.writeTxn(() async {
    await isar.noteModels.put(NoteModel(
      eventId: eventId,
      sig: 'sig',
      authorPubkey: authorPubkey,
      content: content,
      kind: kind,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      created: created ?? tNow,
    ));
  });
}

Future<void> seedUnreadRow(
  Isar isar,
  String eventId, {
  int kind = kNoteKind,
  String authorPubkey = kAlicePub,
  DateTime? created,
}) async {
  await isar.writeTxn(() async {
    await isar.unreadNoteModels.put(UnreadNoteModel()
      ..eventId = eventId
      ..kind = kind
      ..authorPubkey = authorPubkey
      ..created = created ?? tNow);
  });
}

Future<void> seedRelationEdge(
  Isar isar,
  String parentId,
  String childId, {
  DateTime? createdAt,
}) async {
  await isar.writeTxn(() async {
    await isar.noteRelationModels.put(NoteRelationModel()
      ..parentId = parentId
      ..childId = childId
      ..createdAt = createdAt ?? tNow);
  });
}

Future<void> seedReport(
  Isar isar, {
  required String eventId,
  required String reportType,
  String targetPubkey = kSampleTargetPubkeyHex,
  String? targetEventId,
  String content = '',
  DateTime? created,
}) async {
  await isar.writeTxn(() async {
    await isar.reportModels.put(ReportModel()
      ..eventId = eventId
      ..reportType = reportType
      ..targetEventId = targetEventId
      ..targetPubkey = targetPubkey
      ..content = content
      ..created = created ?? tT0);
  });
}
