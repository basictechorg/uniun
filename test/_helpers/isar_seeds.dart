import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/deleted_note_model.dart';
import 'package:uniun/data/models/note_relation_model.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/report_model.dart';

import 'fixtures.dart';

// ── Builders (return the model, no I/O) ─────────────────────────────────────
//
// Use these when several rows go into the same `isar.writeTxn(...)` block —
// batching is faster than one-txn-per-row and lets tests mirror the app's
// atomic-commit pattern. Callers do the `writeTxn` + `put` themselves.

/// Build a [NoteModel] row without committing it.
///
/// All fields have sane defaults. Override any subset:
/// - Feed note (default): `noteRow('ev-1')`
/// - Group message: `noteRow('gm', kind: kGroupMessageKind, groupId: 'g-1')`
/// - DM: `noteRow('dm', kind: kDmTextKind, conversationId: 42)`
/// - Reply: `noteRow('r', rootEventId: 'root', replyToEventId: 'parent')`
/// - Media: `noteRow('m', type: NoteType.image, attachments: [aMediaAttachment(...)])`
NoteModel noteRow(
  String eventId, {
  String content = 'x',
  String authorPubkey = kAlicePub,
  String sig = 'sig',
  int kind = kNoteKind,
  NoteType type = NoteType.text,
  DateTime? created,
  List<String> eTagRefs = const [],
  List<String> pTagRefs = const [],
  List<String> tTags = const [],
  String? rootEventId,
  String? replyToEventId,
  String? groupId,
  String? privateGroupId,
  int? conversationId,
  String? embeddedNoteJson,
  List<MediaAttachment> attachments = const [],
}) =>
    NoteModel(
      eventId: eventId,
      sig: sig,
      authorPubkey: authorPubkey,
      content: content,
      kind: kind,
      type: type,
      eTagRefs: eTagRefs,
      pTagRefs: pTagRefs,
      tTags: tTags,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      groupId: groupId,
      privateGroupId: privateGroupId,
      conversationId: conversationId,
      embeddedNoteJson: embeddedNoteJson,
      attachments: attachments,
      created: created ?? tNow,
    );

/// Build an [UnreadNoteModel] row without committing it.
UnreadNoteModel unreadRow(
  String eventId, {
  int kind = kNoteKind,
  String authorPubkey = kAlicePub,
  String? groupId,
  String? privateGroupId,
  int? conversationId,
  DateTime? created,
}) =>
    UnreadNoteModel()
      ..eventId = eventId
      ..kind = kind
      ..authorPubkey = authorPubkey
      ..groupId = groupId
      ..privateGroupId = privateGroupId
      ..conversationId = conversationId
      ..created = created ?? tNow;

/// Build a [NoteRelationModel] edge row without committing it.
NoteRelationModel relationEdge(
  String parentId,
  String childId, {
  DateTime? createdAt,
}) =>
    NoteRelationModel()
      ..parentId = parentId
      ..childId = childId
      ..createdAt = createdAt ?? tNow;

/// Build a [ReportModel] row without committing it.
ReportModel reportRow({
  required String eventId,
  required String reportType,
  String targetPubkey = kSampleTargetPubkeyHex,
  String? targetEventId,
  String content = '',
  DateTime? created,
}) =>
    ReportModel()
      ..eventId = eventId
      ..reportType = reportType
      ..targetEventId = targetEventId
      ..targetPubkey = targetPubkey
      ..content = content
      ..created = created ?? tT0;

/// Build a [DeletedNoteModel] tombstone row without committing it.
DeletedNoteModel deletedNoteRow(
  String eventId, {
  DateTime? deletedAt,
}) =>
    DeletedNoteModel()
      ..eventId = eventId
      ..deletedAt = deletedAt ?? tNow;

/// Build a [MediaAttachment] embedded row without committing it. Convenient
/// when a test needs a note carrying media via [noteRow]`.attachments`.
MediaAttachment mediaAttachmentRow({
  String sha256 = 'sha',
  String mime = 'image/jpeg',
  int sizeBytes = 42,
  String? url = 'https://s/sha.jpg',
  int? width,
  int? height,
  String? blurhash,
  String? filename,
}) =>
    MediaAttachment()
      ..sha256 = sha256
      ..mime = mime
      ..sizeBytes = sizeBytes
      ..url = url
      ..width = width
      ..height = height
      ..blurhash = blurhash
      ..filename = filename;

// ── Committers (one write per call) ─────────────────────────────────────────
//
// Convenience wrappers when a test only needs to insert one row and doesn't
// care about batching. Each wraps its own `writeTxn`.

Future<void> seedNoteRow(
  Isar isar,
  String eventId, {
  String content = 'x',
  String authorPubkey = kAlicePub,
  int kind = kNoteKind,
  NoteType type = NoteType.text,
  DateTime? created,
  List<String> eTagRefs = const [],
  List<String> pTagRefs = const [],
  List<String> tTags = const [],
  String? rootEventId,
  String? replyToEventId,
  String? groupId,
  String? privateGroupId,
  int? conversationId,
  String? embeddedNoteJson,
  List<MediaAttachment> attachments = const [],
}) async {
  await isar.writeTxn(() async {
    await isar.noteModels.put(noteRow(
      eventId,
      content: content,
      authorPubkey: authorPubkey,
      kind: kind,
      type: type,
      created: created,
      eTagRefs: eTagRefs,
      pTagRefs: pTagRefs,
      tTags: tTags,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      groupId: groupId,
      privateGroupId: privateGroupId,
      conversationId: conversationId,
      embeddedNoteJson: embeddedNoteJson,
      attachments: attachments,
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
    await isar.unreadNoteModels.put(unreadRow(
      eventId,
      kind: kind,
      authorPubkey: authorPubkey,
      created: created,
    ));
  });
}

Future<void> seedRelationEdge(
  Isar isar,
  String parentId,
  String childId, {
  DateTime? createdAt,
}) async {
  await isar.writeTxn(() async {
    await isar.noteRelationModels
        .put(relationEdge(parentId, childId, createdAt: createdAt));
  });
}

Future<void> seedDeletedNote(
  Isar isar,
  String eventId, {
  DateTime? deletedAt,
}) async {
  await isar.writeTxn(() async {
    await isar.deletedNoteModels
        .put(deletedNoteRow(eventId, deletedAt: deletedAt));
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
    await isar.reportModels.put(reportRow(
      eventId: eventId,
      reportType: reportType,
      targetPubkey: targetPubkey,
      targetEventId: targetEventId,
      content: content,
      created: created,
    ));
  });
}
