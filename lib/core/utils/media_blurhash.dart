import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Visual metadata derived from a still image (or a video's thumbnail frame)
/// at pick time: real pixel dimensions + a NIP-92 `blurhash`. Computed once,
/// off the UI thread, then carried on `PickedMedia` through the upload pipeline
/// into the `imeta` tag, so receivers can paint a blurred placeholder before
/// the blob is downloaded.
class MediaPreview {
  const MediaPreview({
    required this.width,
    required this.height,
    required this.blurhash,
  });

  final int width;
  final int height;
  final String blurhash;
}

/// Decodes [imageBytes] and computes its dimensions + a 4×3 blurhash on a
/// background isolate (heavy: full decode + encode). Returns null when the
/// bytes can't be decoded — an unsupported format, a corrupt frame — which
/// callers treat as "no preview", the same graceful-null behaviour image
/// dimensions had before blurhash existed.
Future<MediaPreview?> extractImagePreview(Uint8List imageBytes) {
  return compute(_encodePreview, imageBytes);
}

/// Runs on a background isolate via [compute]; must stay a top-level function.
MediaPreview? _encodePreview(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // A blurhash is a low-frequency placeholder — encoding a full-res frame is
  // pure waste (cost scales with pixel count). Downscale the longest edge to
  // ≤64px first; the resulting hash is visually identical and far cheaper.
  const maxEdge = 64;
  final longest =
      decoded.width >= decoded.height ? decoded.width : decoded.height;
  final small = longest <= maxEdge
      ? decoded
      : decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxEdge)
          : img.copyResize(decoded, height: maxEdge);

  final hash = BlurHash.encode(small, numCompX: 4, numCompY: 3).hash;
  return MediaPreview(
    width: decoded.width,
    height: decoded.height,
    blurhash: hash,
  );
}
