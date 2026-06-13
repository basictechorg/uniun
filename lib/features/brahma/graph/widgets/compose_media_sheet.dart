import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uniun/common/snackbar.dart';
import 'package:uniun/core/constants/app_constants.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/image_compressor.dart';
import 'package:uniun/core/utils/video_compressor.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Opens a Photo / Video / File bottom sheet for the Brahma composer. Picks
/// from the device, reads bytes, decodes image dimensions, and fires
/// [UploadAndAttachMediaEvent] on the parent [BrahmaCreateBloc].
///
/// Kept separate from the compose page so the page stays focused on layout
/// and event wiring — picker plumbing belongs to its own unit.
Future<void> showComposeMediaSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final bloc = context.read<BrahmaCreateBloc>();
  final messenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ComposeMediaTile(
            icon: Icons.image_outlined,
            label: l10n.composerAttachPhoto,
            onTap: () async {
              Navigator.pop(sheetCtx);
              await _pickAndAttachPhoto(bloc, messenger, l10n);
            },
          ),
          _ComposeMediaTile(
            icon: Icons.movie_outlined,
            label: l10n.composerAttachVideo,
            onTap: () async {
              Navigator.pop(sheetCtx);
              await _pickAndAttachVideo(bloc, messenger, l10n);
            },
          ),
          _ComposeMediaTile(
            icon: Icons.attach_file_rounded,
            label: l10n.composerAttachFile,
            onTap: () async {
              Navigator.pop(sheetCtx);
              await _pickAndAttachFile(bloc, messenger, l10n);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _ComposeMediaTile extends StatelessWidget {
  const _ComposeMediaTile({
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

Future<void> _pickAndAttachPhoto(
  BrahmaCreateBloc bloc,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return;
  final raw = await file.readAsBytes();

  // Windows has no native compressor — pass through with a larger cap.
  final budget = Platform.isWindows
      ? AppConstants.kMaxUploadBytesWindows
      : AppConstants.kMaxUploadBytes;

  final compressed = await ImageCompressor.compressToTarget(
    source: raw,
    targetBytes: budget,
  );
  if (compressed == null || compressed.length > budget) {
    AppSnackbar.errorVia(messenger, l10n.mediaTooLargeAfterCompress);
    return;
  }
  // Non-Windows: compressor always emits JPEG. Windows: keep original
  // mime + extension since bytes are unchanged.
  final originalMime = lookupMimeType(file.path) ?? 'image/jpeg';
  final mime = Platform.isWindows ? originalMime : 'image/jpeg';
  final filename = Platform.isWindows
      ? p.basename(file.path)
      : '${p.basenameWithoutExtension(file.path)}.jpg';
  final dim = await _decodeImageDim(compressed);
  bloc.add(UploadAndAttachMediaEvent(
    bytes: compressed,
    mime: mime,
    filename: filename,
    width: dim?.$1,
    height: dim?.$2,
  ));
}

Future<void> _pickAndAttachVideo(
  BrahmaCreateBloc bloc,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (file == null) return;

  // Compresses if needed (Medium → Low → 640×480). Windows is a no-op;
  // the cap check below then surfaces the "compress and try again" error.
  final compressed = await VideoCompressor.compressToTarget(
    sourcePath: file.path,
    targetBytes: AppConstants.kMaxBinaryUploadBytes,
  );
  final upload = compressed ?? File(file.path);
  if (!await _passesUploadCap(upload, messenger, l10n)) return;

  final bytes = await upload.readAsBytes();
  final mime = lookupMimeType(upload.path) ?? 'video/mp4';
  bloc.add(UploadAndAttachMediaEvent(
    bytes: bytes,
    mime: mime,
    filename: p.basename(file.path),
  ));
}

Future<void> _pickAndAttachFile(
  BrahmaCreateBloc bloc,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  // withData:false → file_picker returns the path only and does NOT slurp
  // the whole file into memory. We size-check the path first, then load
  // bytes manually only if it passes.
  final result = await FilePicker.platform.pickFiles(withData: false);
  if (result == null || result.files.isEmpty) return;
  final picked = result.files.first;
  final path = picked.path;
  if (path == null) return;
  final fileHandle = File(path);
  if (!await _passesUploadCap(fileHandle, messenger, l10n)) return;
  final bytes = await fileHandle.readAsBytes();
  final mime = lookupMimeType(picked.name) ?? 'application/octet-stream';
  bloc.add(UploadAndAttachMediaEvent(
    bytes: bytes,
    mime: mime,
    filename: picked.name,
  ));
}

/// Hard size gate for videos and arbitrary files against
/// [AppConstants.kMaxBinaryUploadBytes]. Over the cap → snackbar; under
/// → pass through. Avoids the relay's nginx returning a bare 413.
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

/// Decodes [bytes] only far enough to read intrinsic width/height. Returns
/// null for non-image data. The [ui.Image] is disposed immediately — we
/// only need the two integers to populate the imeta `dim WxH` field.
/// Formats a byte count as B / KB / MB for upload-cap snackbars.
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
