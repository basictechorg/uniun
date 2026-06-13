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
  // Compress to fit the relay's request-body limit. Most phone photos are
  // 3-8 MB; nginx in front of the relay caps at 1 MB. We aim slightly
  // under to leave room for the auth header.
  final compressed = await ImageCompressor.compressToTarget(
    source: raw,
    targetBytes: AppConstants.kMaxUploadBytes,
  );
  if (compressed == null || compressed.length > AppConstants.kMaxUploadBytes) {
    AppSnackbar.errorVia(messenger, l10n.mediaTooLargeAfterCompress);
    return;
  }
  // Always advertise compressed output as JPEG — flutter_image_compress
  // always re-encodes to JPEG regardless of input format.
  const mime = 'image/jpeg';
  final dim = await _decodeImageDim(compressed);
  bloc.add(UploadAndAttachMediaEvent(
    bytes: compressed,
    mime: mime,
    filename: '${p.basenameWithoutExtension(file.path)}.jpg',
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
  if (!await _passesUploadCap(File(file.path), messenger, l10n)) return;
  final bytes = await file.readAsBytes();
  final mime = lookupMimeType(file.path) ?? 'video/mp4';
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

/// Hard size gate for videos and arbitrary files (we don't transcode either
/// — recompressing video on-device is out of scope for v1). Returns true
/// when the file is under [AppConstants.kMaxUploadBytes].
Future<bool> _passesUploadCap(
  File file,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  try {
    final size = await file.length();
    if (size <= AppConstants.kMaxUploadBytes) return true;
    final kb = (size / 1024).toStringAsFixed(0);
    final capKb =
        (AppConstants.kMaxUploadBytes / 1024).toStringAsFixed(0);
    AppSnackbar.errorVia(messenger, l10n.mediaTooLarge(kb, capKb));
    return false;
  } catch (_) {
    return true;
  }
}

/// Decodes [bytes] only far enough to read intrinsic width/height. Returns
/// null for non-image data. The [ui.Image] is disposed immediately — we
/// only need the two integers to populate the imeta `dim WxH` field.
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
