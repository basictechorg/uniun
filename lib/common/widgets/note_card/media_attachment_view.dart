import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/snackbar.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Renders the NIP-92 `imeta` attachments on a [NoteEntity]. Attachments
/// are pre-resolved by `NoteAttachmentsEnricher`; this widget never reads
/// Isar. Each tile owns its own download state so one blob arriving doesn't
/// re-render the feed.
///
/// [compact] caps image height tight for feeds / DMs / quotes; false gives
/// the thread parent more room.
class MediaAttachmentView extends StatelessWidget {
  const MediaAttachmentView({
    super.key,
    required this.note,
    this.compact = true,
  });

  final NoteEntity note;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (note.attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in note.attachments) ...[
            _AttachmentTile(
              key: ValueKey(b.sha256),
              initial: b,
              compact: compact,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({
    super.key,
    required this.initial,
    required this.compact,
  });
  final MediaBlobEntity initial;
  final bool compact;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  late MediaBlobEntity _blob = widget.initial;
  bool _downloading = false;

  /// Compact: feed / DM / quote card. Expanded: thread parent.
  /// Excess height is cropped via `BoxFit.cover`; full aspect lives on the
  /// detail page.
  static const double _compactMaxHeight = 200.0;
  static const double _expandedMaxHeight = 360.0;

  bool get _cached => _blob.localPath != null;
  bool get _isImage => _blob.mime.startsWith('image/');

  Future<void> _download() async {
    setState(() => _downloading = true);
    final res = await getIt<DownloadMediaUseCase>().call(_blob.sha256);
    if (!mounted) return;
    setState(() {
      _downloading = false;
      res.fold((_) {}, (newBlob) => _blob = newBlob);
    });
    res.fold(
      (f) => AppSnackbar.error(context, f.toMessage()),
      (_) {},
    );
  }

  /// Image → detail page. Everything else → download if needed, then hand
  /// the local file to the OS via `OpenFilex`.
  Future<void> _onTap() async {
    if (_isImage) {
      context.pushNamed(
        AppRoutes.mediaDetail,
        pathParameters: {'sha256': _blob.sha256},
      );
      return;
    }
    if (!_cached) {
      await _download();
      if (!mounted) return;
    }
    final path = _blob.localPath;
    if (path == null) return;
    await OpenFilex.open(path);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImage) return _FileCard(blob: _blob, busy: _downloading, onTap: _onTap);

    final l10n = AppLocalizations.of(context)!;
    final maxH = widget.compact ? _compactMaxHeight : _expandedMaxHeight;

    return GestureDetector(
      onTap: _onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          final aspect = _blob.dim == null
              ? 16 / 9
              : _blob.dim!.width / _blob.dim!.height;
          // Natural height for full-width display, then clamp so portraits
          // don't push the rest of the card off-screen.
          final naturalH = width / aspect;
          final height = naturalH.clamp(0.0, maxH);

          return SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _background(),
                  if (!_cached) _downloadOverlay(l10n),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _downloadOverlay(AppLocalizations l10n) {
    return Container(
      color: Colors.black.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: _downloading
          ? const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : ElevatedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(l10n.noteCardDownloadMedia),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
              ),
            ),
    );
  }

  Widget _background() {
    if (_cached && _isImage) {
      return Image.file(
        File(_blob.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (!_cached && _isImage && _blob.blurhash != null) {
      return BlurHash(hash: _blob.blurhash!);
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final icon = _blob.mime.startsWith('video/')
        ? Icons.movie_outlined
        : _blob.mime.startsWith('audio/')
            ? Icons.audiotrack_outlined
            : Icons.insert_drive_file_outlined;
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(icon, size: 48, color: AppColors.onSurfaceVariant),
    );
  }
}

/// Horizontal card for non-image attachments: type chip, filename + meta,
/// trailing download/open icon. Tap → download (if needed) then OS handoff.
class _FileCard extends StatelessWidget {
  const _FileCard({required this.blob, required this.busy, required this.onTap});

  final MediaBlobEntity blob;
  final bool busy;
  final VoidCallback onTap;

  bool get _cached => blob.localPath != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = _FileTypeStyle.fromMime(blob.mime, blob.filename);
    final title = (blob.filename != null && blob.filename!.trim().isNotEmpty)
        ? blob.filename!
        : l10n.noteCardFileFallbackName;
    final subtitle = _buildSubtitle(l10n, style);

    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _typeChip(style),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _trailing(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(_FileTypeStyle style) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(style.icon, color: style.color, size: 22),
          const SizedBox(height: 2),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: style.color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailing() {
    if (busy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }
    return Icon(
      _cached ? Icons.open_in_new_rounded : Icons.cloud_download_outlined,
      size: 20,
      color: AppColors.onSurfaceVariant,
    );
  }

  String _buildSubtitle(AppLocalizations l10n, _FileTypeStyle style) {
    final parts = <String>[style.readableType];
    if (blob.sizeBytes > 0) parts.add(_humanBytes(blob.sizeBytes));
    parts.add(_cached ? l10n.noteCardFileTapToOpen : l10n.noteCardFileTapToDownload);
    return parts.join(' · ');
  }

  static String _humanBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

/// Visual identity for a non-image attachment. Type is encoded by [label]
/// and [icon]; color is always [AppColors.primary] for visual consistency.
class _FileTypeStyle {
  const _FileTypeStyle({
    required this.label,
    required this.readableType,
    required this.icon,
  });

  /// 3-4 char chip abbreviation ("PDF", "XLSX", "MP4").
  final String label;

  /// Subtitle label ("PDF Document", "Spreadsheet").
  final String readableType;
  final IconData icon;

  Color get color => AppColors.primary;

  static _FileTypeStyle fromMime(String mime, String? filename) {
    final ext = _extOf(filename, mime);
    switch (ext) {
      case 'pdf':
        return const _FileTypeStyle(
          label: 'PDF',
          readableType: 'PDF Document',
          icon: Icons.picture_as_pdf_outlined,
        );
      case 'doc':
      case 'docx':
        return _FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Word Document',
          icon: Icons.description_outlined,
        );
      case 'xls':
      case 'xlsx':
      case 'csv':
        return _FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Spreadsheet',
          icon: Icons.table_chart_outlined,
        );
      case 'ppt':
      case 'pptx':
        return _FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Presentation',
          icon: Icons.slideshow_outlined,
        );
      case 'zip':
      case 'rar':
      case '7z':
        return _FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Archive',
          icon: Icons.folder_zip_outlined,
        );
      case 'txt':
      case 'md':
        return _FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Text',
          icon: Icons.notes_outlined,
        );
    }
    if (mime.startsWith('video/')) {
      return _FileTypeStyle(
        label: ext.isEmpty ? 'VID' : ext.toUpperCase(),
        readableType: 'Video',
        icon: Icons.play_circle_outline,
      );
    }
    if (mime.startsWith('audio/')) {
      return _FileTypeStyle(
        label: ext.isEmpty ? 'AUD' : ext.toUpperCase(),
        readableType: 'Audio',
        icon: Icons.audiotrack_outlined,
      );
    }
    return _FileTypeStyle(
      label: ext.isEmpty ? 'FILE' : ext.toUpperCase(),
      readableType: 'File',
      icon: Icons.insert_drive_file_outlined,
    );
  }

  /// Prefer filename extension over mime mapping — filenames are accurate
  /// when present; mime is `application/octet-stream` for anything the OS
  /// picker couldn't sniff.
  static String _extOf(String? filename, String mime) {
    if (filename != null) {
      final dot = filename.lastIndexOf('.');
      if (dot >= 0 && dot < filename.length - 1) {
        return filename.substring(dot + 1).toLowerCase();
      }
    }
    const mimeExt = {
      'application/pdf': 'pdf',
      'application/msword': 'doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
      'application/vnd.ms-excel': 'xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
      'application/vnd.ms-powerpoint': 'ppt',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
      'text/csv': 'csv',
      'text/plain': 'txt',
      'application/zip': 'zip',
      'application/x-rar-compressed': 'rar',
      'application/x-7z-compressed': '7z',
    };
    return mimeExt[mime.toLowerCase()] ?? '';
  }
}
