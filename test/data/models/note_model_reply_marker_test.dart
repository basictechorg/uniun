import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/notes/note_model.dart';

/// Regression guard for #76 — direct replies to a thread root must populate
/// both `rootEventId` AND `replyToEventId` so the thread BFS finds them.
void main() {
  Event ev(List<List<String>> tags) => Event.fromJson({
        'id': 'a' * 64,
        'pubkey': 'b' * 64,
        'created_at': 1700000000,
        'kind': 1,
        'tags': tags,
        'content': 'reply',
        'sig': 'c' * 128,
      }, verify: false);

  test('direct reply (root marker == reply marker id) populates both fields',
      () {
    final m = NoteModel.fromEvent(ev([
      ['e', 'root_id', '', 'root'],
      ['e', 'root_id', '', 'reply'],
    ]));
    expect(m.rootEventId, 'root_id');
    expect(m.replyToEventId, 'root_id');
  });

  test('legacy event with only root marker leaves replyToEventId null', () {
    // Documents the pre-fix wire shape — confirms the parser does NOT silently
    // promote a lone root marker into a reply marker. Old events stay parsed
    // the way they were sent.
    final m = NoteModel.fromEvent(ev([
      ['e', 'root_id', '', 'root'],
    ]));
    expect(m.rootEventId, 'root_id');
    expect(m.replyToEventId, isNull);
  });
}
