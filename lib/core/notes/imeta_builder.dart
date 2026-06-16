import 'package:uniun/domain/entities/media/media_blob_entity.dart';

/// Builds NIP-92 `imeta` tags from attached blobs. One tag per blob; each is
/// a string array `["imeta", "url ...", "m ...", "x ...", ...]`.
///
/// Tag order matters when the publisher re-serializes for the wire — the
/// signed event hash depends on the original order. This helper is the
/// single source so every surface (feed / channel / DM / private channel)
/// produces identical bytes.
List<List<String>> buildImetaTags(List<MediaBlobEntity> blobs) {
  final out = <List<String>>[];
  for (final b in blobs) {
    final url = b.serverUrls.isNotEmpty ? b.serverUrls.first : '';
    if (url.isEmpty) continue;
    final dim = b.dim;
    out.add([
      'imeta',
      'url $url',
      'm ${b.mime}',
      'x ${b.sha256}',
      if (b.sizeBytes > 0) 'size ${b.sizeBytes}',
      if (dim != null) 'dim ${dim.width}x${dim.height}',
      if (b.blurhash != null) 'blurhash ${b.blurhash}',
      if (b.filename != null && b.filename!.isNotEmpty) 'name ${b.filename}',
    ]);
  }
  return out;
}
