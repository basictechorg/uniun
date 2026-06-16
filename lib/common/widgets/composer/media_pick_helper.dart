import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uniun/common/snackbar.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/image_compressor.dart';
import 'package:uniun/core/utils/video_compressor.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// One picked + compressed file ready to hand to `UploadMediaUseCase`. The
/// caller owns the upload step so each surface (Brahma / chat / DM) can
/// decide where the resulting blob attaches.
class PickedMedia {
  const PickedMedia({
    required this.bytes,
    required this.mime,
    required this.filename,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mime;
  final String filename;
  final int? width;
  final int? height;
}

enum _PickKind { photo, video, file }

/// Shows the Photo / Video / File picker bottom sheet. Returns the picked
/// (and where applicable, compressed) file, or null when the user dismissed
/// the sheet or the chosen file exceeded the upload cap after compression.
///
/// Two-stage: the bottom sheet only selects *which kind* of picker to open
/// (popping the sheet with a `_PickKind` value). The actual picker runs
/// **after** the sheet has fully dismissed — otherwise the modal's `await`
/// would resolve as soon as `Navigator.pop` runs and the async picker work
/// would race with the caller continuing on, returning null too early.
///
/// Surface-agnostic — does not know about any bloc. Windows skips
/// compression because neither flutter_image_compress nor video_compress
/// have a Windows backend.
Future<PickedMedia?> showMediaPickSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  final kind = await showModalBottomSheet<_PickKind>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PickTile(
            icon: Icons.image_outlined,
            label: l10n.composerAttachPhoto,
            onTap: () => Navigator.pop(sheetCtx, _PickKind.photo),
          ),
          _PickTile(
            icon: Icons.movie_outlined,
            label: l10n.composerAttachVideo,
            onTap: () => Navigator.pop(sheetCtx, _PickKind.video),
          ),
          _PickTile(
            icon: Icons.attach_file_rounded,
            label: l10n.composerAttachFile,
            onTap: () => Navigator.pop(sheetCtx, _PickKind.file),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (kind == null) return null; // user dismissed the sheet

  switch (kind) {
    case _PickKind.photo:
      return _pickPhoto(messenger, l10n);
    case _PickKind.video:
      return _pickVideo(messenger, l10n);
    case _PickKind.file:
      return _pickFile(messenger, l10n);
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: onTap,
    );
  }
}

Future<PickedMedia?> _pickPhoto(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  final raw = await file.readAsBytes();

  final budget = Platform.isWindows
      ? AppConstants.kMaxUploadBytesWindows
      : AppConstants.kMaxUploadBytes;

  final compressed = await ImageCompressor.compressToTarget(
    source: raw,
    targetBytes: budget,
  );
  if (compressed == null || compressed.length > budget) {
    AppSnackbar.errorVia(messenger, l10n.mediaTooLargeAfterCompress);
    return null;
  }
  final originalMime = lookupMimeType(file.path) ?? 'image/jpeg';
  final mime = Platform.isWindows ? originalMime : 'image/jpeg';
  final filename = Platform.isWindows
      ? p.basename(file.path)
      : '${p.basenameWithoutExtension(file.path)}.jpg';
  final dim = await _decodeImageDim(compressed);
  return PickedMedia(
    bytes: compressed,
    mime: mime,
    filename: filename,
    width: dim?.$1,
    height: dim?.$2,
  );
}

Future<PickedMedia?> _pickVideo(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (file == null) return null;

  final compressed = await VideoCompressor.compressToTarget(
    sourcePath: file.path,
    targetBytes: AppConstants.kMaxBinaryUploadBytes,
  );
  final upload = compressed ?? File(file.path);
  if (!await _passesUploadCap(upload, messenger, l10n)) return null;

  final bytes = await upload.readAsBytes();
  final mime = lookupMimeType(upload.path) ?? 'video/mp4';
  return PickedMedia(
    bytes: bytes,
    mime: mime,
    filename: p.basename(file.path),
  );
}

Future<PickedMedia?> _pickFile(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  // withData:false → file_picker returns the path only and does NOT slurp
  // the whole file into memory. Size-check the path first.
  final result = await FilePicker.platform.pickFiles(withData: false);
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.first;
  final path = picked.path;
  if (path == null) return null;
  final fileHandle = File(path);
  if (!await _passesUploadCap(fileHandle, messenger, l10n)) return null;
  final bytes = await fileHandle.readAsBytes();
  final mime = lookupMimeType(picked.name) ?? 'application/octet-stream';
  return PickedMedia(
    bytes: bytes,
    mime: mime,
    filename: picked.name,
  );
}

Future<bool> _passesUploadCap(
  File file,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  try {
    final size = await file.length();
    if (size <= AppConstants.kMaxBinaryUploadBytes) return true;
    AppSnackbar.errorVia(
      messenger,
      l10n.mediaTooLarge(
        _humanBytes(size),
        _humanBytes(AppConstants.kMaxBinaryUploadBytes),
      ),
    );
    return false;
  } catch (_) {
    return true;
  }
}

String _humanBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

Future<(int, int)?> _decodeImageDim(Uint8List bytes) async {
  try {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    final img = await completer.future;
    final dim = (img.width, img.height);
    img.dispose();
    return dim;
  } catch (_) {
    return null;
  }
}
