// Round-trip tests for [FollowedNoteBody] — the plaintext body shape carried
// inside a Kind-30501 mesh event. Pure Dart, no plugin channels, no Isar.

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/features/mesh/sync/bodies/followed_note_body.dart';

void main() {
  test('forActive → applyBody preserves every column', () {
    final src = FollowedNoteModel()
      ..eventId = 'ev-1'
      ..contentPreview = 'preview 🚀'
      ..followedAt = DateTime.fromMillisecondsSinceEpoch(1720000100000);

    final body = FollowedNoteBody.forActive(src);
    expect(body['state'], 'active');

    final round = FollowedNoteBody.applyBody(body, eventId: 'ev-1');
    expect(round.eventId, 'ev-1');
    expect(round.contentPreview, 'preview 🚀');
    expect(round.followedAt.millisecondsSinceEpoch, 1720000100000);
  });

  test('forRemoved emits state=removed but carries full row shape', () {
    final src = FollowedNoteModel()
      ..eventId = 'ev-r'
      ..contentPreview = 'gone'
      ..followedAt = DateTime.fromMillisecondsSinceEpoch(1720000200000);

    final body = FollowedNoteBody.forRemoved(src);
    expect(body['state'], 'removed');

    final round = FollowedNoteBody.applyBody(body, eventId: 'ev-r');
    expect(round.contentPreview, 'gone');
    expect(round.followedAt.millisecondsSinceEpoch, 1720000200000);
  });

  test('applyBody updates an existing row in place', () {
    final existing = FollowedNoteModel()
      ..eventId = 'ev-x'
      ..contentPreview = 'old'
      ..followedAt = DateTime.fromMillisecondsSinceEpoch(0);

    final src = FollowedNoteModel()
      ..eventId = 'ev-x'
      ..contentPreview = 'new'
      ..followedAt = DateTime.fromMillisecondsSinceEpoch(1720000300000);

    final round = FollowedNoteBody.applyBody(
      FollowedNoteBody.forActive(src),
      eventId: 'ev-x',
      existing: existing,
    );
    expect(identical(round, existing), isTrue);
    expect(round.contentPreview, 'new');
  });

  test('applyBody tolerates missing optional fields', () {
    final round = FollowedNoteBody.applyBody(<String, dynamic>{
      'state': 'active',
      // no followedAt, no contentPreview
    }, eventId: 'x');
    expect(round.contentPreview, '');
    expect(round.followedAt.millisecondsSinceEpoch, 0);
  });
}
