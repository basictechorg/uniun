import 'dart:io';
import 'dart:typed_data';

import 'package:video_compress/video_compress.dart';

/// Iterative video compression. Walks `_schedule` (`VideoQuality` tiers,
/// each maps to a native bitrate) until output drops below [targetBytes].
/// Returns the source unchanged if it already fits, best-effort if no tier
/// fits, or null if the platform refused.
///
/// Windows has no native backend — [compressToTarget] returns the source
/// [File] unchanged and the caller's cap gate produces the error.
///
/// Callers may invoke `VideoCompress.deleteAllCache()` after upload — we
/// don't, since bytes may be read more than once.
class VideoCompressor {
  VideoCompressor._();

  static const List<VideoQuality> _schedule = [
    VideoQuality.MediumQuality,
    VideoQuality.LowQuality,
    VideoQuality.Res640x480Quality,
  ];

  /// Returns a [File] under [targetBytes] when possible, source unchanged
  /// when it already fits or on Windows, or best-effort over budget.
  static Future<File?> compressToTarget({
    required String sourcePath,
    required int targetBytes,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    if (await source.length() <= targetBytes) return source;

    if (Platform.isWindows) return source;

    File? best;
    for (final quality in _schedule) {
      try {
        final info = await VideoCompress.compressVideo(
          sourcePath,
          quality: quality,
          deleteOrigin: false,
        );
        final outPath = info?.path;
        if (outPath == null) continue;
        final candidate = File(outPath);
        if (!await candidate.exists()) continue;
        best = candidate;
        if (await candidate.length() <= targetBytes) return candidate;
      } catch (_) {
        // Native side refused this preset — try the next.
      }
    }
    return best; // may still be over budget — caller checks and errors out
  }

  /// Extracts a single representative still frame of the video at [sourcePath]
  /// as JPEG bytes — used to derive a `blurhash` + dimensions for the NIP-92
  /// `imeta` tag so the video shows a blurred preview before download. Returns
  /// null on Windows (no backend) or when the native side refuses.
  static Future<Uint8List?> thumbnailBytes(String sourcePath) async {
    if (Platform.isWindows) return null;
    try {
      return await VideoCompress.getByteThumbnail(
        sourcePath,
        quality: 50,
      );
    } catch (_) {
      return null;
    }
  }
}
