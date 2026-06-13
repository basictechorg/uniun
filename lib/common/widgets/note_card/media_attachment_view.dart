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

/// Renders the attachments (NIP-92 `imeta`) carried by a [NoteEntity]. The
/// attachments are pre-resolved by the data layer (see
/// `NoteAttachmentsEnricher`) — this widget is stateless and never touches
/// the DB. Each tile owns its own download lifecycle locally so the feed
/// doesn't have to refresh just because one blob's bytes arrived.
///
/// Twitter/X-style behaviour:
///   • [compact] (default) — feed cards, embedded quotes, DM bubbles.
///     Image height is capped tight so a portrait photo doesn't dominate
///     the card. Extra is cropped via `BoxFit.cover`.
///   • `compact: false` — thread parent only. Taller cap so the original
///     post can breathe; rest of the feed stays compact.
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

  /// Height caps tuned for scan-ability — note cards stay compact so a tall
  /// portrait photo doesn't push the rest of the card off-screen. Detail
  /// page is the place to view a blob at full aspect.
  ///   • feed / DM / quote card  ~ 200 logical px
  ///   • thread parent           ~ 360 logical px
  /// Anything taller than the cap is cropped via BoxFit.cover.
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
    // Surface failure so the user knows why nothing happened — silent
    // swallowing made cross-device download bugs invisible during testing.
    res.fold(
      (f) => AppSnackbar.error(context, f.toMessage()),
      (_) {},
    );
  }

  /// Tap routing:
  ///   • image  → MediaDetailPage (renders full-aspect preview).
  ///   • everything else (video, pdf, file, …) → download if needed, then
  ///     hand the local file to the OS so the user actually sees / plays /
  ///     reads it, instead of staring at metadata.
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
