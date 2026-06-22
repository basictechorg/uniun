import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/common/widgets/media/file_type_style.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';

/// Grid tile for the Media gallery. Images render the cached file directly;
/// every other mime (pdf / mp4 / docx …) renders the same chip+label tile
/// the feed uses, so the gallery doesn't show empty grey squares.
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
                  child: DropLoadingIndicator(size: 24),
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
        errorBuilder: (_, __, ___) => _fileTile(),
      );
    }
    return _fileTile();
  }

  /// Same visual language as `_FileCard` in `media_attachment_view.dart`,
  /// laid out vertically for a square grid cell: tinted background, big
  /// icon, type chip, optional filename truncated below.
  Widget _fileTile() {
    final style = FileTypeStyle.fromMime(blob.mime, blob.filename);
    final filename = blob.filename?.trim();
    return Container(
      color: style.color.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(style.icon, size: 34, color: style.color),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: style.color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              style.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (filename != null && filename.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
