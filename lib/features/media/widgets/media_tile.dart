import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

/// Grid tile for the Media gallery. Renders the cached image directly, or
/// a mime-icon placeholder for non-image files. The gallery only lists
/// blobs that are already on disk, so there is no "remote-only" state to
/// signal — no cache badge.
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
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_isImage && blob.localPath != null) {
      return Image.file(
        File(blob.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
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
