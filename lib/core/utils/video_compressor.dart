import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// Iterative video compression to fit a byte budget.
///
/// Unlike images we cannot dial JPEG quality directly — the underlying
/// platform encoder picks bitrate per [VideoQuality] tier. We walk a small
/// schedule (medium → low → 640×480) and return the first variant under
/// the budget. Returns the original [File] if it already fits, the best
/// effort otherwise, or `null` if the platform compressor refused.
///
/// **Windows:** `video_compress` has no Windows backend. We detect this
/// and return the source [File] unchanged so the picker still completes —
/// the caller's size-cap gate then prints the standard "too large" error.
///
/// The native side does the heavy lifting on a background thread; the
/// returned Future completes once the temp output file is ready. Callers
/// may invoke `VideoCompress.deleteAllCache()` once the upload settles —
/// we don't do it here because the bytes might be read more than once.
class VideoCompressor {
  VideoCompressor._();

  static const List<VideoQuality> _schedule = [
    VideoQuality.MediumQuality,
    VideoQuality.LowQuality,
    VideoQuality.Res640x480Quality,
  ];

  /// Returns a [File] under [targetBytes] when possible. On Windows the
  /// source is passed through unchanged (no native compressor). On other
  /// platforms we walk the quality schedule and return the first fit,
  /// falling back to best-effort if none of the presets shrink it enough.
  static Future<File?> compressToTarget({
    required String sourcePath,
    required int targetBytes,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    if (await source.length() <= targetBytes) return source;

    // Windows has no native backend — return source so the caller's cap
    // check handles the snackbar consistently.
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
}
