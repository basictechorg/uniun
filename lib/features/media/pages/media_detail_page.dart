import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/features/media/cubit/media_detail_cubit.dart';
import 'package:uniun/l10n/app_localizations.dart';

class MediaDetailPage extends StatelessWidget {
  const MediaDetailPage({super.key, required this.sha256});

  final String sha256;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MediaDetailCubit(sha256: sha256)..load(),
      child: const _MediaDetailView(),
    );
  }
}

class _MediaDetailView extends StatelessWidget {
  const _MediaDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<MediaDetailCubit, MediaDetailState>(
      builder: (context, state) {
        final blob = state.blob;
        return Scaffold(
          backgroundColor: AppColors.surfaceContainerLowest,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceContainerLowest,
            elevation: 0,
            foregroundColor: AppColors.onSurface,
            title: Text(blob?.mime ?? l10n.mediaGalleryTitle,
                style: const TextStyle(fontSize: 14)),
          ),
          body: blob == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _DetailBody(blob: blob, refIds: state.referencingNoteIds),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.blob, required this.refIds});

  final MediaBlobEntity blob;
  final List<String> refIds;

  bool get _isImage => blob.mime.startsWith('image/');
  bool get _cached => blob.localPath != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<MediaDetailCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: blob.dim == null
                ? 1
                : blob.dim!.width / blob.dim!.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _preview(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Actions row ────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_cached)
                _action(
                  Icons.cloud_download_outlined,
                  l10n.mediaActionDownload,
                  cubit.download,
                ),
              // Non-image cached blobs: hand off to the OS so the user can
              // actually view the PDF / play the video / read the file.
              if (_cached && !_isImage)
                _action(
                  Icons.open_in_new_rounded,
                  l10n.mediaActionOpen,
                  () => OpenFilex.open(blob.localPath!),
                ),
              _action(
                blob.pinned ? Icons.star : Icons.star_outline,
                blob.pinned ? l10n.mediaActionUnpin : l10n.mediaActionPin,
                cubit.togglePin,
              ),
              if (_cached)
                _action(
                  Icons.delete_outline,
                  l10n.mediaActionRemoveLocal,
                  cubit.removeLocal,
                  destructive: true,
                ),
              _action(
                Icons.fingerprint,
                l10n.mediaActionCopySha,
                () {
                  Clipboard.setData(ClipboardData(text: blob.sha256));
                },
              ),
              if (blob.serverUrls.isNotEmpty)
                _action(
                  Icons.link,
                  l10n.mediaActionCopyUrl,
                  () {
                    Clipboard.setData(
                        ClipboardData(text: blob.serverUrls.first));
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Metadata ───────────────────────────────────────────────────
          _metaRow(l10n.mediaDetailLabelSha, blob.sha256),
          _metaRow(l10n.mediaDetailLabelMime, blob.mime),
          _metaRow(l10n.mediaDetailLabelSize, _fmtBytes(blob.sizeBytes)),
          if (blob.dim != null)
            _metaRow(l10n.mediaDetailLabelDim,
                '${blob.dim!.width} × ${blob.dim!.height}'),
          if (blob.downloadedAt != null)
            _metaRow(l10n.mediaDetailLabelCached, _fmtDate(blob.downloadedAt!)),
          _metaRow(l10n.mediaDetailReferencedBy, refIds.length.toString()),
          for (final url in blob.serverUrls)
            _metaRow(l10n.mediaDetailLabelServer, url),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_cached && _isImage) {
      return Image.file(
        File(blob.localPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholderForMime(),
      );
    }
    if (!_cached && _isImage && blob.blurhash != null) {
      return BlurHash(hash: blob.blurhash!);
    }
    return _placeholderForMime();
  }

  Widget _placeholderForMime() {
    final IconData icon = blob.mime.startsWith('video/')
        ? Icons.movie_outlined
        : blob.mime.startsWith('audio/')
            ? Icons.audiotrack_outlined
            : Icons.insert_drive_file_outlined;
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(icon, size: 64, color: AppColors.onSurfaceVariant),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
