import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Iterative JPEG compression to fit a byte budget. Walks `_schedule`
/// (quality, longest-edge) until output drops below [targetBytes] or the
/// schedule is exhausted. Re-encodes HEIC / PNG / WebP to JPEG.
///
/// Windows has no native backend — [compressToTarget] returns [source]
/// unchanged. Callers must use [AppConstants.kMaxUploadBytesWindows] there.
class ImageCompressor {
  ImageCompressor._();

  /// (quality 0–100, longest-edge cap in pixels). Floor is 60q / 1600px;
  /// anything that won't fit there is unlikely to fit at all.
  static const List<(int, int)> _schedule = [
    (95, 4096),
    (90, 3072),
    (85, 2560),
    (80, 2048),
    (70, 1920),
    (60, 1600),
  ];

  /// Returns [source] unchanged when already under [targetBytes] or when
  /// running on Windows (no native backend). Otherwise compresses
  /// iteratively. Null on failure.
  static Future<Uint8List?> compressToTarget({
    required Uint8List source,
    required int targetBytes,
  }) async {
    if (source.length <= targetBytes) return source;
    if (Platform.isWindows) return source;

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
