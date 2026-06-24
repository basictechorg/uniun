import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

part 'draft_entity.freezed.dart';

@freezed
abstract class DraftEntity with _$DraftEntity {
  const factory DraftEntity({
    required String draftId,
    required String content,
    String? rootEventId,
    String? replyToEventId,
    required List<String> eTagRefs,
    required List<String> pTagRefs,
    required List<String> tTags,
    required DateTime createdAt,
    required DateTime updatedAt,

    /// Media attached to the draft. Staged **locally only** (bytes live in the
    /// shared media cache, keyed by sha256) — NOT uploaded to Blossom while a
    /// draft. `localPath` is patched in from the cache on read so the draft
    /// renders like any note; `serverUrls` stays empty until the draft is
    /// published, at which point the bytes are uploaded and `imeta` is built.
    @Default(<MediaBlobEntity>[]) List<MediaBlobEntity> attachments,
  }) = _DraftEntity;
}
