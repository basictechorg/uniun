import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/data/models/draft_model.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';

/// DraftModel ↔ DraftEntity mapping. The model is the Isar side (mutable);
/// the entity is the domain side (freezed). Every persisted field — including
/// the link-survival fields `draftRefIds` and `publishedAsEventId` and the
/// staged-local-only `attachments` list — must round-trip cleanly.
void main() {
  DraftModel buildModel({
    String draftId = 'draft-uuid-1',
    String content = 'hello',
    String? rootEventId,
    String? replyToEventId,
    List<String> eTagRefs = const [],
    List<String> pTagRefs = const [],
    List<String> tTags = const [],
    List<String> draftRefIds = const [],
    String? publishedAsEventId,
    List<MediaAttachment> attachments = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DraftModel()
      ..draftId = draftId
      ..content = content
      ..rootEventId = rootEventId
      ..replyToEventId = replyToEventId
      ..eTagRefs = List<String>.from(eTagRefs)
      ..pTagRefs = List<String>.from(pTagRefs)
      ..tTags = List<String>.from(tTags)
      ..draftRefIds = List<String>.from(draftRefIds)
      ..publishedAsEventId = publishedAsEventId
      ..attachments = attachments
      ..createdAt = createdAt ?? DateTime(2026, 6, 1)
      ..updatedAt = updatedAt ?? DateTime(2026, 6, 2);
  }

  MediaAttachment imeta(String sha) => MediaAttachment()
    ..sha256 = sha
    ..mime = 'image/jpeg'
    ..sizeBytes = 1024
    ..url = null
    ..width = 100
    ..height = 200
    ..blurhash = 'LFE.@D9F01_2%MIVjsRj0KWB}@of'
    ..filename = 'pic.jpg';

  group('DraftModel.toDomain', () {
    test('round-trips every persisted field', () {
      final m = buildModel(
        draftId: 'd-1',
        content: 'body',
        rootEventId: 'root',
        replyToEventId: 'parent',
        eTagRefs: ['root', 'parent', 'mention1'],
        pTagRefs: ['pubkey1'],
        tTags: ['topic'],
        draftRefIds: ['ref-uuid-1', 'ref-uuid-2'],
        publishedAsEventId: null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      final e = m.toDomain();

      expect(e.draftId, 'd-1');
      expect(e.content, 'body');
      expect(e.rootEventId, 'root');
      expect(e.replyToEventId, 'parent');
      expect(e.eTagRefs, ['root', 'parent', 'mention1']);
      expect(e.pTagRefs, ['pubkey1']);
      expect(e.tTags, ['topic']);
      expect(e.draftRefIds, ['ref-uuid-1', 'ref-uuid-2']);
      expect(e.publishedAsEventId, isNull);
      expect(e.attachments, isEmpty);
      expect(e.createdAt, DateTime(2026, 1, 1));
      expect(e.updatedAt, DateTime(2026, 1, 2));
    });

    test('top-level draft → rootEventId/replyToEventId null, NIP-10 fields skipped', () {
      final e = buildModel().toDomain();
      expect(e.rootEventId, isNull);
      expect(e.replyToEventId, isNull);
    });

    test('tombstone draft carries publishedAsEventId', () {
      // The repo hides these from getDrafts, but the mapping itself must pass
      // it through so the inbound NIP-37 sweep can read it.
      final e = buildModel(publishedAsEventId: 'evt-id').toDomain();
      expect(e.publishedAsEventId, 'evt-id');
    });

    test('attachments map to MediaBlobEntity preserving sha + dimensions', () {
      final e = buildModel(attachments: [imeta('sha-a'), imeta('sha-b')]).toDomain();
      expect(e.attachments.map((a) => a.sha256).toList(), ['sha-a', 'sha-b']);
      expect(e.attachments.first.mime, 'image/jpeg');
      expect(e.attachments.first.sizeBytes, 1024);
      expect(e.attachments.first.dim?.width, 100);
      expect(e.attachments.first.dim?.height, 200);
      expect(e.attachments.first.blurhash, isNotNull);
      // Local cache state is patched in by the enricher, not by toDomain.
      expect(e.attachments.first.localPath, isNull);
      expect(e.attachments.first.downloadedAt, isNull);
      // serverUrls empty while a draft — bytes never reach Blossom until publish.
      expect(e.attachments.first.serverUrls, isEmpty);
    });

    test('attachment with no dim → entity.dim is null (not 0×0)', () {
      final m = buildModel(attachments: [
        MediaAttachment()
          ..sha256 = 'sha-c'
          ..mime = 'application/pdf'
          ..sizeBytes = 4096
      ]);
      final e = m.toDomain();
      expect(e.attachments.single.dim, isNull);
    });

    test('draftRefIds defaults to empty when not provided', () {
      // Freezed default — important for backwards-compat with old Isar rows
      // that never set the field (Isar schema additivity returns const []).
      final e = buildModel().toDomain();
      expect(e.draftRefIds, isEmpty);
    });
  });
}
