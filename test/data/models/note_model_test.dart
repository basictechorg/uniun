import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/notes/note_model.dart';

/// Pure-logic tests for the unified Note collection — no Isar required.
///
/// Coverage:
///   - kind-keyed `toDomain()` mapping (1 / 42 / 14 / 9023) routes the right
///     container field onto the entity
///   - NIP-10 e-tag marker parsing populates `rootEventId` / `replyToEventId`
///     while keeping every id in `eTagRefs`
///   - `decodeEmbeddedNote` returns null for absent / unparseable snapshots
void main() {
  group('NoteModel.toDomain — kind discriminator', () {
    NoteModel base({
      required int kind,
      String? groupId,
      String? privateGroupId,
      int? conversationId,
    }) {
      return NoteModel(
        eventId: 'evt',
        sig: 'sig',
        authorPubkey: 'pk',
        content: 'hi',
        kind: kind,
        groupId: groupId,
        privateGroupId: privateGroupId,
        conversationId: conversationId,
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime(2026, 1, 1),
      );
    }

    test('kind 1 → top-level feed note (no container)', () {
      final e = base(kind: kNoteKind).toDomain();
      expect(e.kind, kNoteKind);
      expect(e.sourceGroupId, isNull);
      expect(e.sourcePrivateGroupId, isNull);
      expect(e.conversationId, isNull);
    });

    test('kind 42 → group message carries sourceGroupId', () {
      final e =
          base(kind: kGroupMessageKind, groupId: 'ch1').toDomain();
      expect(e.kind, kGroupMessageKind);
      expect(e.sourceGroupId, 'ch1');
      expect(e.sourcePrivateGroupId, isNull);
      expect(e.conversationId, isNull);
    });

    test('kind 14 → DM carries conversationId', () {
      final e = base(kind: kDmTextKind, conversationId: 7).toDomain();
      expect(e.kind, kDmTextKind);
      expect(e.conversationId, 7);
      expect(e.sourceGroupId, isNull);
      expect(e.sourcePrivateGroupId, isNull);
    });

    test('kind 9023 → private group carries sourcePrivateGroupId', () {
      final e =
          base(kind: kPrivateGroupKind, privateGroupId: 'grp:abc').toDomain();
      expect(e.kind, kPrivateGroupKind);
      expect(e.sourcePrivateGroupId, 'grp:abc');
      expect(e.sourceGroupId, isNull);
      expect(e.conversationId, isNull);
    });
  });

  group('NoteModel.fromEvent — NIP-10 e-tag parsing', () {
    Event buildEvent(List<List<String>> tags) {
      return Event.fromJson({
        'id': 'a' * 64,
        'pubkey': 'b' * 64,
        'created_at': 1700000000,
        'kind': 1,
        'tags': tags,
        'content': 'body',
        'sig': 'c' * 128,
      }, verify: false);
    }

    test('root marker lands in rootEventId; mention stays in eTagRefs only',
        () {
      final ev = buildEvent([
        ['e', 'root_id', '', 'root'],
        ['e', 'mention_id', '', 'mention'],
      ]);
      final m = NoteModel.fromEvent(ev);
      expect(m.rootEventId, 'root_id');
      expect(m.replyToEventId, isNull);
      expect(m.eTagRefs, containsAll(['root_id', 'mention_id']));
    });

    test('reply marker lands in replyToEventId', () {
      final ev = buildEvent([
        ['e', 'root_id', '', 'root'],
        ['e', 'parent_id', '', 'reply'],
      ]);
      final m = NoteModel.fromEvent(ev);
      expect(m.rootEventId, 'root_id');
      expect(m.replyToEventId, 'parent_id');
    });

    test('e-tag without marker still counted in eTagRefs but no role assigned',
        () {
      final ev = buildEvent([
        ['e', 'bare_id'],
      ]);
      final m = NoteModel.fromEvent(ev);
      expect(m.eTagRefs, ['bare_id']);
      expect(m.rootEventId, isNull);
      expect(m.replyToEventId, isNull);
    });
  });

  group('decodeEmbeddedNote', () {
    test('returns null for null input', () {
      expect(decodeEmbeddedNote(null), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(decodeEmbeddedNote('{not json'), isNull);
    });
  });
}
