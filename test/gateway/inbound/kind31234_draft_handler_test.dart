import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nip44/nip44.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/draft_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind31234_draft_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../../_helpers/isar_test_harness.dart';

/// Integration tests for the inbound NIP-37 draft wrap handler.
///
/// Uses real secp256k1 keys + real NIP-44 encryption so the handler's
/// decrypt path is exercised end-to-end. Each test:
///   1. builds an inner Kind-1 event (the draft body),
///   2. encrypts it with NIP-44,
///   3. wraps it as a Kind-31234 outer event,
///   4. calls `handler.handle(...)`, and
///   5. asserts the resulting [DraftModel] state in Isar.
void main() {
  late Isar isar;
  late Keychain me;
  late Keychain someoneElse;
  late Kind31234DraftHandler handler;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    someoneElse = Keychain.generate();
    handler = Kind31234DraftHandler(
      activePubkey: me.public,
      activePrivkey: me.private,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<VerifiedNostrEvent> buildWrap({
    required String draftId,
    required Keychain author,
    required int createdAtSec,
    String? innerContent = 'draft body',
    List<List<String>> innerTags = const [],
    String? overrideOuterContent,
  }) async {
    final inner = <String, dynamic>{
      'kind': kNoteKind,
      'pubkey': author.public,
      'created_at': createdAtSec,
      'tags': innerTags,
      'content': innerContent,
    };
    final encrypted =
        overrideOuterContent ??
        await Nip44.encryptMessage(
          jsonEncode(inner),
          author.private,
          author.public,
        );
    return trustedEvent(<String, dynamic>{
      'id': 'evt-$createdAtSec-${draftId.hashCode}',
      'pubkey': author.public,
      'created_at': createdAtSec,
      'kind': kDraftWrapKind,
      'content': encrypted,
      'tags': [
        ['d', draftId],
        ['k', kNoteKind.toString()],
      ],
    });
  }

  test('decrypts a wrap from self and writes a fresh DraftModel row', () async {
    final wrap = await buildWrap(
      draftId: 'draft-1',
      author: me,
      createdAtSec: 1_700_000_000,
      innerContent: 'hello from the relay',
      innerTags: [
        ['e', 'root-id', '', 'root'],
        ['e', 'mention-id', '', 'mention'],
        ['p', 'pubkey-tag'],
        ['t', 'topic'],
      ],
    );

    await handler.handle(wrap, isar);

    final row = await isar.draftModels
        .filter()
        .draftIdEqualTo('draft-1')
        .findFirst();
    expect(row, isNotNull);
    expect(row!.content, 'hello from the relay');
    expect(row.rootEventId, 'root-id');
    expect(row.replyToEventId, isNull);
    expect(row.eTagRefs, ['root-id', 'mention-id']);
    expect(row.pTagRefs, ['pubkey-tag']);
    expect(row.tTags, ['topic']);
    expect(row.lastSyncedEventId, wrap.id);
  });

  test('ignores wraps authored by someone else', () async {
    final wrap = await buildWrap(
      draftId: 'evil',
      author: someoneElse,
      createdAtSec: 1_700_000_000,
    );
    await handler.handle(wrap, isar);
    expect(await isar.draftModels.where().count(), 0);
  });

  test('no-op when there is no active user', () async {
    final wrap = await buildWrap(
      draftId: 'd-1',
      author: me,
      createdAtSec: 1_700_000_000,
    );
    final noUserHandler = Kind31234DraftHandler(
      activePubkey: null,
      activePrivkey: null,
    );
    await noUserHandler.handle(wrap, isar);
    expect(await isar.draftModels.where().count(), 0);
  });

  test('last-write-wins by created_at — older wrap is ignored', () async {
    await handler.handle(
      await buildWrap(
        draftId: 'd-1',
        author: me,
        createdAtSec: 1_700_000_100,
        innerContent: 'newer',
      ),
      isar,
    );
    await handler.handle(
      await buildWrap(
        draftId: 'd-1',
        author: me,
        createdAtSec: 1_700_000_000,
        innerContent: 'older — should be ignored',
      ),
      isar,
    );
    final row = (await isar.draftModels
        .filter()
        .draftIdEqualTo('d-1')
        .findFirst())!;
    expect(row.content, 'newer');
  });

  test('newer wrap replaces older row (content + tags overwritten)', () async {
    await handler.handle(
      await buildWrap(
        draftId: 'd-1',
        author: me,
        createdAtSec: 1_700_000_000,
        innerContent: 'v1',
        innerTags: [
          ['t', 'old'],
        ],
      ),
      isar,
    );
    await handler.handle(
      await buildWrap(
        draftId: 'd-1',
        author: me,
        createdAtSec: 1_700_000_100,
        innerContent: 'v2',
        innerTags: [
          ['t', 'new'],
        ],
      ),
      isar,
    );
    final row = (await isar.draftModels
        .filter()
        .draftIdEqualTo('d-1')
        .findFirst())!;
    expect(row.content, 'v2');
    expect(row.tTags, ['new']);
  });

  test(
    'empty outer content = NIP-37 deletion signal → local row removed',
    () async {
      await handler.handle(
        await buildWrap(
          draftId: 'd-1',
          author: me,
          createdAtSec: 1_700_000_000,
          innerContent: 'will be deleted',
        ),
        isar,
      );
      expect(await isar.draftModels.where().count(), 1);

      final tombstone = trustedEvent(<String, dynamic>{
        'id': 'evt-tomb',
        'pubkey': me.public,
        'created_at': 1_700_000_100,
        'kind': kDraftWrapKind,
        'content': '',
        'tags': [
          ['d', 'd-1'],
          ['k', kNoteKind.toString()],
        ],
      });
      await handler.handle(tombstone, isar);
      expect(await isar.draftModels.where().count(), 0);
    },
  );

  test('deletion of a draft that was never local is a silent no-op', () async {
    final tombstone = trustedEvent(<String, dynamic>{
      'id': 'evt-tomb',
      'pubkey': me.public,
      'created_at': 1_700_000_000,
      'kind': kDraftWrapKind,
      'content': '',
      'tags': [
        ['d', 'ghost'],
      ],
    });
    await handler.handle(tombstone, isar);
    expect(await isar.draftModels.where().count(), 0);
  });

  test('parses d-ref tags into draftRefIds', () async {
    await handler.handle(
      await buildWrap(
        draftId: 'parent',
        author: me,
        createdAtSec: 1_700_000_000,
        innerTags: [
          ['d-ref', 'child-uuid-1'],
          ['d-ref', 'child-uuid-2'],
        ],
      ),
      isar,
    );
    final row = (await isar.draftModels
        .filter()
        .draftIdEqualTo('parent')
        .findFirst())!;
    expect(row.draftRefIds, ['child-uuid-1', 'child-uuid-2']);
  });

  test(
    'parses published-as tag into publishedAsEventId (tombstone propagation)',
    () async {
      await handler.handle(
        await buildWrap(
          draftId: 'd-1',
          author: me,
          createdAtSec: 1_700_000_000,
          innerTags: [
            ['published-as', 'evt-real'],
          ],
        ),
        isar,
      );
      final row = (await isar.draftModels
          .filter()
          .draftIdEqualTo('d-1')
          .findFirst())!;
      expect(row.publishedAsEventId, 'evt-real');
    },
  );

  test(
    'cross-device sweep: published-as triggers local UUID→eventId rewrite',
    () async {
      // Seed a local 'parent' draft that references 'child-uuid' (the draft we
      // haven't yet seen the tombstone for).
      await isar.writeTxn(() async {
        await isar.draftModels.put(
          DraftModel()
            ..draftId = 'parent'
            ..content = 'parent body'
            ..eTagRefs = const []
            ..pTagRefs = const []
            ..tTags = const []
            ..draftRefIds = ['child-uuid']
            ..createdAt = DateTime(2026, 1, 1)
            ..updatedAt = DateTime(2026, 1, 1),
        );
      });

      // Tombstone for 'child-uuid' arrives from the other device.
      await handler.handle(
        await buildWrap(
          draftId: 'child-uuid',
          author: me,
          createdAtSec: 1_700_000_000,
          innerTags: [
            ['published-as', 'evt-child'],
          ],
        ),
        isar,
      );

      final parent = (await isar.draftModels
          .filter()
          .draftIdEqualTo('parent')
          .findFirst())!;
      expect(parent.draftRefIds, isEmpty);
      expect(parent.eTagRefs, contains('evt-child'));
    },
  );

  test(
    'reply marker lands in replyToEventId; mention stays in eTagRefs only',
    () async {
      await handler.handle(
        await buildWrap(
          draftId: 'r-1',
          author: me,
          createdAtSec: 1_700_000_000,
          innerTags: [
            ['e', 'root-id', '', 'root'],
            ['e', 'parent-id', '', 'reply'],
            ['e', 'mention-id', '', 'mention'],
          ],
        ),
        isar,
      );
      final row = (await isar.draftModels
          .filter()
          .draftIdEqualTo('r-1')
          .findFirst())!;
      expect(row.rootEventId, 'root-id');
      expect(row.replyToEventId, 'parent-id');
      // eTagRefs holds ALL e-tag ids (root, reply, mention).
      expect(row.eTagRefs, ['root-id', 'parent-id', 'mention-id']);
    },
  );

  test(
    'malformed (non-decryptable) content is dropped silently — no row written',
    () async {
      final wrap = trustedEvent(<String, dynamic>{
        'id': 'evt-junk',
        'pubkey': me.public,
        'created_at': 1_700_000_000,
        'kind': kDraftWrapKind,
        'content': 'this-is-not-nip44-ciphertext',
        'tags': [
          ['d', 'd-1'],
        ],
      });
      await handler.handle(wrap, isar);
      expect(await isar.draftModels.where().count(), 0);
    },
  );

  test('missing d-tag → handler bails without writing', () async {
    final inner = <String, dynamic>{
      'kind': kNoteKind,
      'pubkey': me.public,
      'created_at': 1_700_000_000,
      'tags': [],
      'content': 'body',
    };
    final encrypted = await Nip44.encryptMessage(
      jsonEncode(inner),
      me.private,
      me.public,
    );
    final wrap = trustedEvent(<String, dynamic>{
      'id': 'evt-no-d',
      'pubkey': me.public,
      'created_at': 1_700_000_000,
      'kind': kDraftWrapKind,
      'content': encrypted,
      'tags': [
        ['k', kNoteKind.toString()],
      ],
    });
    await handler.handle(wrap, isar);
    expect(await isar.draftModels.where().count(), 0);
  });

  test('preserves original createdAt across resyncs', () async {
    await handler.handle(
      await buildWrap(
        draftId: 'd-1',
        author: me,
        createdAtSec: 1_700_000_000,
        innerContent: 'v1',
      ),
      isar,
    );
    final firstCreated =
        (await isar.draftModels.filter().draftIdEqualTo('d-1').findFirst())!
            .createdAt;

    await handler.handle(
      await buildWrap(
        draftId: 'd-1',
        author: me,
        createdAtSec: 1_700_001_000,
        innerContent: 'v2',
      ),
      isar,
    );
    final row = (await isar.draftModels
        .filter()
        .draftIdEqualTo('d-1')
        .findFirst())!;
    expect(
      row.createdAt,
      firstCreated,
      reason: 'createdAt frozen on first write',
    );
    expect(row.updatedAt.isAfter(firstCreated), isTrue);
  });
}

VerifiedNostrEvent trustedEvent(Map<String, dynamic> raw) {
  return VerifiedNostrEvent(
    id: raw['id'] as String,
    pubkey: raw['pubkey'] as String,
    createdAt: raw['created_at'] as int,
    kind: raw['kind'] as int,
    tags: (raw['tags'] as List)
        .map((tag) => (tag as List).cast<String>())
        .toList(),
    content: raw['content'] as String,
    sig: raw['sig'] as String? ?? '',
    raw: raw,
  );
}
