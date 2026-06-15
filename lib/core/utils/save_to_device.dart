import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Result of a save-to-device attempt. UI uses [destination] for the
/// confirmation snackbar; null means the operation was cancelled or
/// failed silently.
class SaveResult {
  const SaveResult({required this.success, this.destination, this.error});

  final bool success;

  /// Human-readable description of where the file was saved
  /// ("Photos", "Downloads", "<path>"). Null for share-sheet fallbacks
  /// where the OS owns the destination choice.
  final String? destination;
  final String? error;
}

/// Saves a cached media file straight to the device, picking the most
/// native flow per platform + mime:
///
/// - **Image / video on Android / iOS / macOS** — `gal` writes directly
///   to Photos. Permissions are requested via `Gal.requestAccess()`.
/// - **Image / video on Windows** — copied to the user's Downloads folder.
/// - **Other files (PDF / doc / etc.) on Android / iOS** — share sheet
///   ("Save to Files" is the standard mobile flow for non-media).
/// - **Other files on macOS / Windows** — copied to Downloads.
///
/// Required manifest entries:
/// - Android: `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>`
///   and `WRITE_EXTERNAL_STORAGE` (≤ SDK 28). See gal docs.
/// - iOS: `NSPhotoLibraryAddUsageDescription` in `Info.plist`.
Future<SaveResult> saveMediaToDevice({
  required String localPath,
  required String mime,
  String? filename,
}) async {
  try {
    final isImage = mime.startsWith('image/');
    final isVideo = mime.startsWith('video/');
    final isMedia = isImage || isVideo;

    if (isMedia &&
        (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          return const SaveResult(
            success: false,
            error: 'Photos permission denied',
          );
        }
      }
      if (isImage) {
        await Gal.putImage(localPath, album: 'UNIUN');
      } else {
        await Gal.putVideo(localPath, album: 'UNIUN');
      }
      return const SaveResult(success: true, destination: 'Photos');
    }

    // Desktop image/video, or any non-media on desktop: copy into Downloads.
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final destName = filename ?? p.basename(localPath);
        final dest = File(p.join(downloads.path, destName));
        await File(localPath).copy(dest.path);
        return SaveResult(success: true, destination: dest.path);
      }
    }

    // Non-media on Android / iOS — share sheet has the right "Save to
    // Files" affordance.
    await Share.shareXFiles([XFile(localPath, name: filename)]);
    return const SaveResult(success: true);
  } catch (e, st) {
    debugPrint('saveMediaToDevice failed: $e\n$st');
    return SaveResult(success: false, error: e.toString());
  }
}
