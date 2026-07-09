import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/event_queue_model.dart';

import '../../_helpers/isar_seeds.dart';

/// Verifies the EventQueue canonical serializer emits NIP-56-shaped `e`/`p`
/// tags when `reportType` is set, and otherwise keeps the standard NIP-10
/// root/reply/mention shape. The relay rejects any deviation since the
/// signature is computed against this exact byte sequence.
void main() {
  EventQueueModel buildRow({
    required int kind,
    List<String> eTagRefs = const [],
    List<String> pTagRefs = const [],
    String? reportType,
    String? rootEventId,
    String? replyToEventId,
  }) =>
      eventQueueRow(
        'a' * 64,
        authorPubkey: 'b' * 64,
        sig: 'c' * 128,
        content: 'reason',
        kind: kind,
        eTagRefs: eTagRefs,
        pTagRefs: pTagRefs,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        reportType: reportType,
      );

  List<List<String>> tagsOf(String serialized) {
    final outer = jsonDecode(serialized) as List<dynamic>;
    final payload = outer[1] as Map<String, dynamic>;
    return (payload['tags'] as List<dynamic>)
        .map((t) => (t as List<dynamic>).cast<String>())
        .toList();
  }

  test('NIP-56 report note → e tag carries report type as 4th entry', () {
    final row = buildRow(
      kind: kReportKind,
      eTagRefs: ['target_evt'],
      pTagRefs: ['target_pubkey'],
      reportType: 'spam',
    );
    final tags = tagsOf(row.toSerializedRelayMessage());
    expect(tags, [
      ['e', 'target_evt', '', 'spam'],
      ['p', 'target_pubkey', 'spam'],
    ]);
  });

  test('NIP-56 report user (no e tag) → only p tag carries the type', () {
    final row = buildRow(
      kind: kReportKind,
      eTagRefs: const [],
      pTagRefs: ['target_pubkey'],
      reportType: 'impersonation',
    );
    final tags = tagsOf(row.toSerializedRelayMessage());
    expect(tags, [
      ['p', 'target_pubkey', 'impersonation'],
    ]);
  });

  test('Kind 1 root/reply markers are not affected when reportType is null',
      () {
    final row = buildRow(
      kind: kNoteKind,
      eTagRefs: ['root_id', 'parent_id', 'mention_id'],
      pTagRefs: const ['mentioned_user'],
      rootEventId: 'root_id',
      replyToEventId: 'parent_id',
    );
    final tags = tagsOf(row.toSerializedRelayMessage());
    expect(tags, [
      ['e', 'root_id', '', 'root'],
      ['e', 'parent_id', '', 'reply'],
      ['e', 'mention_id', '', 'mention'],
      ['p', 'mentioned_user'],
    ]);
  });

  test('reportType pre-empts NIP-10 markers even if rootEventId is set', () {
    // Belt-and-braces: the serializer must NOT emit a stray ["e", root, "",
    // "root"] line when reportType is non-null. Future code that accidentally
    // sets rootEventId on a Kind-1984 row shouldn't corrupt the wire shape.
    final row = buildRow(
      kind: kReportKind,
      eTagRefs: ['target_evt'],
      pTagRefs: ['target_pubkey'],
      reportType: 'illegal',
      rootEventId: 'target_evt',
    );
    final tags = tagsOf(row.toSerializedRelayMessage());
    expect(tags, [
      ['e', 'target_evt', '', 'illegal'],
      ['p', 'target_pubkey', 'illegal'],
    ]);
  });
}
