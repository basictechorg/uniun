import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/core/utils/save_to_device.dart';
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
            leading: const UniunBackButton(),
            title: Text(blob?.mime ?? l10n.mediaGalleryTitle,
                style: const TextStyle(fontSize: 14)),
          ),
          body: blob == null
              ? const Center(
                  child: DropLoadingIndicator(color: AppColors.primary),
                )
              : _DetailBody(blob: blob),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.blob});

  final MediaBlobEntity blob;

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
              if (_cached && !_isImage)
                _action(
                  Icons.open_in_new_rounded,
                  l10n.mediaActionOpen,
                  () => OpenFilex.open(blob.localPath!),
                ),
              if (_cached)
                _action(
                  Icons.save_alt_rounded,
                  l10n.mediaActionSaveToDevice,
                  () => _saveToDevice(context, blob, l10n),
                ),
              if (_cached)
                _action(
                  Icons.delete_outline,
                  l10n.mediaActionRemoveLocal,
                  () async {
                    final ok = await cubit.removeLocal();
                    if (ok && context.mounted) Navigator.of(context).pop();
                  },
                  destructive: true,
                ),
              _action(
                Icons.fingerprint,
                l10n.mediaActionCopySha,
                () {
                  Clipboard.setData(ClipboardData(text: blob.sha256));
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

  Future<void> _saveToDevice(
    BuildContext context,
    MediaBlobEntity blob,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await saveMediaToDevice(
      localPath: blob.localPath!,
      mime: blob.mime,
      filename: blob.filename,
    );
    if (!context.mounted) return;
    // User dismissed the system save picker — no snackbar, no error noise.
    if (result.cancelled) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
        result.success
            ? (result.destination != null
                ? l10n.mediaSavedTo(result.destination!)
                : l10n.mediaSaveSuccess)
            : (result.error ?? l10n.mediaSaveFailed),
      ),
      backgroundColor:
          result.success ? AppColors.primary : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
