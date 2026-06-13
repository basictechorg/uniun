import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

/// Grid tile rendering a [MediaBlobEntity]. When the blob is not yet cached
/// locally, falls back to blurhash → mime icon. Badges show pin / cache state.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.blob,
    required this.busy,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  final MediaBlobEntity blob;
  final bool busy;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  bool get _isImage => blob.mime.startsWith('image/');
  bool get _cached => blob.localPath != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildBackground(),
          ),
          if (busy)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.topRight,
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 22),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Row(
              children: [
                if (blob.pinned)
                  const _Badge(
                    icon: Icons.star,
                    color: AppColors.tertiary,
                  ),
                if (blob.pinned && _cached) const SizedBox(width: 4),
                if (_cached)
                  const _Badge(
                    icon: Icons.download_done_rounded,
                    color: AppColors.primary,
                  )
                else
                  _Badge(
                    icon: Icons.cloud_download_outlined,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
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
    final IconData icon;
    if (blob.mime.startsWith('image/')) {
      icon = Icons.image_outlined;
    } else if (blob.mime.startsWith('video/')) {
      icon = Icons.movie_outlined;
    } else if (blob.mime.startsWith('audio/')) {
      icon = Icons.audiotrack_outlined;
    } else {
      icon = Icons.insert_drive_file_outlined;
    }
    return Container(
      color: AppColors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.onSurfaceVariant, size: 36),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
