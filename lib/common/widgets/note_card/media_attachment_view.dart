import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Renders any media (NIP-92 `imeta`) attached to a note. Inbound notes
/// arrive with `localPath == null` — the tile shows the blurhash or a mime
/// icon plus a "Download" button. Once cached, the image renders inline.
///
/// Stateful because download / pin / remove actions need to refresh the
/// linked blob list locally without rebuilding the whole feed.
class MediaAttachmentView extends StatefulWidget {
  const MediaAttachmentView({super.key, required this.noteEventId});

  final String noteEventId;

  @override
  State<MediaAttachmentView> createState() => _MediaAttachmentViewState();
}

class _MediaAttachmentViewState extends State<MediaAttachmentView> {
  List<MediaBlobEntity> _blobs = const [];
  bool _loaded = false;
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant MediaAttachmentView old) {
    super.didUpdateWidget(old);
    if (old.noteEventId != widget.noteEventId) _reload();
  }

  Future<void> _reload() async {
    final res =
        await getIt<GetBlobsForNoteUseCase>().call(widget.noteEventId);
    if (!mounted) return;
    res.fold(
      (_) => setState(() => _loaded = true),
      (blobs) => setState(() {
        _blobs = blobs;
        _loaded = true;
      }),
    );
  }

  Future<void> _download(String sha256) async {
    setState(() => _downloading.add(sha256));
    await getIt<DownloadMediaUseCase>().call(sha256);
    if (!mounted) return;
    setState(() => _downloading.remove(sha256));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _blobs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in _blobs) ...[
            _AttachmentTile(
              blob: b,
              downloading: _downloading.contains(b.sha256),
              onDownload: () => _download(b.sha256),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.blob,
    required this.downloading,
    required this.onDownload,
  });

  final MediaBlobEntity blob;
  final bool downloading;
  final VoidCallback onDownload;

  bool get _cached => blob.localPath != null;
  bool get _isImage => blob.mime.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aspect = blob.dim == null
        ? 16 / 9
        : blob.dim!.width / blob.dim!.height;
    return GestureDetector(
      onTap: () => context.pushNamed(
        AppRoutes.mediaDetail,
        extra: blob.sha256,
        pathParameters: {'sha256': blob.sha256},
      ),
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _background(),
              if (!_cached)
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  alignment: Alignment.center,
                  child: downloading
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: onDownload,
                          icon: const Icon(Icons.cloud_download_outlined,
                              size: 18),
                          label: Text(l10n.noteCardDownloadMedia),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _background() {
    if (_cached && _isImage) {
      return Image.file(
        File(blob.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (!_cached && _isImage && blob.blurhash != null) {
      return BlurHash(hash: blob.blurhash!);
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final icon = blob.mime.startsWith('video/')
        ? Icons.movie_outlined
        : blob.mime.startsWith('audio/')
            ? Icons.audiotrack_outlined
            : Icons.insert_drive_file_outlined;
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(icon, size: 48, color: AppColors.onSurfaceVariant),
    );
  }
}
