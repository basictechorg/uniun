import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/features/media/cubit/media_gallery_cubit.dart';
import 'package:uniun/features/media/cubit/media_gallery_state.dart';
import 'package:uniun/features/media/widgets/media_tile.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Modal bottom sheet that lets the composer pick an already-known blob (no
/// upload, no download — just reuses an existing sha256 reference). Returns
/// the picked [MediaBlobEntity] or null on cancel.
class MediaPickerSheet extends StatelessWidget {
  const MediaPickerSheet({super.key});

  static Future<MediaBlobEntity?> show(BuildContext context) {
    return showModalBottomSheet<MediaBlobEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const MediaPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => MediaGalleryCubit()..load(),
      child: SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      l10n.mediaPickerTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<MediaGalleryCubit, MediaGalleryState>(
                  builder: (context, state) {
                    if (state.status == MediaGalleryStatus.loading) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      );
                    }
                    if (state.blobs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.mediaPickerEmpty,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: state.blobs.length,
                      itemBuilder: (context, i) {
                        final b = state.blobs[i];
                        return MediaTile(
                          key: ValueKey(b.sha256),
                          blob: b,
                          busy: false,
                          onTap: () => Navigator.of(context).pop(b),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
