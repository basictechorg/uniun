import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Iterative image compression to fit a byte budget.
///
/// Reduces JPEG quality and bounds the longest edge progressively until the
/// output drops below [targetBytes] or we've exhausted the schedule. Returns
/// null when even the smallest setting can't fit (extremely small budget +
/// bizarre input); the caller surfaces an error.
///
/// HEIC, PNG, WebP inputs all come back as JPEG — a sensible default for
/// photo attachments. PNG with transparency is out of scope for v1 (most
/// chat-style photos don't need alpha).
class ImageCompressor {
  ImageCompressor._();

  /// (quality 0–100, longest-edge cap in pixels). Tuned for the 3 MB budget:
  /// the first step is near-pristine for most phone photos, and we never
  /// fall below 60q / 1600px so receivers see a clean image, not a JPEG
  /// stew. Anything that won't fit at 60/1600 was probably never going to.
  static const List<(int, int)> _schedule = [
    (95, 4096),
    (90, 3072),
    (85, 2560),
    (80, 2048),
    (70, 1920),
    (60, 1600),
  ];

  /// Returns [source] unchanged when already under [targetBytes]. Otherwise
  /// compresses iteratively. Null on failure.
  static Future<Uint8List?> compressToTarget({
    required Uint8List source,
    required int targetBytes,
  }) async {
    if (source.length <= targetBytes) return source;

    Uint8List? best;
    for (final step in _schedule) {
      final (quality, maxEdge) = step;
      try {
        final out = await FlutterImageCompress.compressWithList(
          source,
          quality: quality,
          minWidth: maxEdge,
          minHeight: maxEdge,
          format: CompressFormat.jpeg,
        );
        best = out;
        if (out.length <= targetBytes) return out;
      } catch (_) {
        // Native codec rejected the input — try the next setting.
      }
    }
    return best; // best effort even if over budget
  }
}
