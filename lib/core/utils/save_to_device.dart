import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of a save-to-device attempt. UI uses [destination] for the
/// confirmation snackbar; null means the operation was cancelled or
/// failed silently.
class SaveResult {
  const SaveResult({required this.success, this.destination, this.error});

  final bool success;

  /// Human-readable description of where the file was saved
  /// ("Photos", "Downloads", "<path>"). Null when the user cancelled the
  /// picker — UI should not show a success snackbar in that case.
  final String? destination;
  final String? error;

  /// User dismissed the system picker — distinct from a failed write.
  bool get cancelled => !success && error == null;
}

/// Saves a cached media file to the device, choosing the most native flow
/// per platform + mime so the user is never dropped into a share sheet
/// when a real "Save as…" dialog exists.
///
/// | Platform     | Image / Video                  | PDF / Doc / Other            |
/// |--------------|--------------------------------|------------------------------|
/// | Android      | `ImageGallerySaverPlus` → Photos | `FlutterFileDialog` → SAF picker |
/// | iOS          | `ImageGallerySaverPlus` → Photos | `FlutterFileDialog` → "Save to Files" |
/// | macOS        | `ImageGallerySaverPlus` → Photos | `FilePicker.saveFile()` → NSSavePanel + copy |
/// | Windows      | Copy to Downloads              | Copy to Downloads            |
/// | Linux        | Copy to Downloads              | Copy to Downloads            |
///
/// Required manifest entries:
/// - Android: `READ_MEDIA_IMAGES` (+ `WRITE_EXTERNAL_STORAGE` on ≤ SDK 28)
///   for `ImageGallerySaverPlus`. SAF writes need no extra permission.
/// - iOS: `NSPhotoLibraryAddUsageDescription` in `Info.plist` (already set).
Future<SaveResult> saveMediaToDevice({
  required String localPath,
  required String mime,
  String? filename,
}) async {
  try {
    final isMedia =
        mime.startsWith('image/') || mime.startsWith('video/');

    // ── Images / videos → Photos (Android / iOS / macOS) ─────────────────
    if (isMedia &&
        (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      final result = await ImageGallerySaverPlus.saveFile(
        localPath,
        name: filename ?? p.basenameWithoutExtension(localPath),
      );
      final saved = result['isSuccess'] == true;
      if (!saved) {
        return SaveResult(
          success: false,
          error: result['errorMessage']?.toString() ?? 'Save failed',
        );
      }
      return const SaveResult(success: true, destination: 'Photos');
    }

    // ── Android / iOS non-media → SAF / Files picker ─────────────────────
    // Android: opens the system "Save as" picker (Downloads, Drive, custom).
    // iOS:     opens "Save to Files" without the noisy share-sheet apps.
    if (Platform.isAndroid || Platform.isIOS) {
      final saved = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: localPath,
          fileName: filename ?? p.basename(localPath),
        ),
      );
      if (saved == null) {
        return const SaveResult(success: false);
      }
      return SaveResult(success: true, destination: saved);
    }

    // ── macOS non-media → native NSSavePanel via file_picker ─────────────
    // `saveFile` only returns the chosen path on desktop; we copy the
    // bytes ourselves.
    if (Platform.isMacOS) {
      final outPath = await FilePicker.platform.saveFile(
        fileName: filename ?? p.basename(localPath),
      );
      if (outPath == null) {
        return const SaveResult(success: false);
      }
      await File(localPath).copy(outPath);
      return SaveResult(success: true, destination: outPath);
    }

    // ── Windows / Linux → copy into the user's Downloads folder ──────────
    if (Platform.isWindows || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final destName = filename ?? p.basename(localPath);
        final dest = File(p.join(downloads.path, destName));
        await File(localPath).copy(dest.path);
        return SaveResult(success: true, destination: dest.path);
      }
    }

    return const SaveResult(success: false, error: 'Unsupported platform');
  } catch (e, st) {
    debugPrint('saveMediaToDevice failed: $e\n$st');
    return SaveResult(success: false, error: e.toString());
  }
}
