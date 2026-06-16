import 'package:isar_community/isar.dart';

part 'media_attachment.g.dart';

/// One NIP-92 `imeta` attachment, embedded directly on [NoteModel.attachments].
/// Mirrors the wire-format `imeta` tag — every field has a one-to-one
/// correspondence with the published tag substrings.
///
/// "Where the bytes live on this device" is NOT here — that's [MediaCacheModel]
/// keyed by [sha256]. This struct only describes the file.
@embedded
class MediaAttachment {
  late String sha256;
  late String mime;
  int sizeBytes = 0;
  String? url;
  int? width;
  int? height;
  String? blurhash;
  String? filename;
}
