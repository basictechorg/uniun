import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/features/media/cubit/media_gallery_cubit.dart';
import 'package:uniun/features/media/cubit/media_gallery_state.dart';
import 'package:uniun/features/media/widgets/media_tile.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class MediaGalleryPage extends StatelessWidget {
  const MediaGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MediaGalleryCubit()..load(),
      child: const _MediaGalleryView(),
    );
  }
}

class _MediaGalleryView extends StatelessWidget {
  const _MediaGalleryView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        title: Text(l10n.mediaGalleryTitle),
        foregroundColor: AppColors.onSurface,
      ),
      body: BlocBuilder<MediaGalleryCubit, MediaGalleryState>(
        builder: (context, state) {
          return Column(
            children: [
              _FilterStrip(state: state),
              Expanded(child: _Grid(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.state});

  final MediaGalleryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<MediaGalleryCubit>();
    final f = state.filter;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chip(l10n.mediaTabAll, f.kind == MediaKindFilter.all, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.all));
          }),
          _chip(l10n.mediaTabImages, f.kind == MediaKindFilter.image, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.image));
          }),
          _chip(l10n.mediaTabVideos, f.kind == MediaKindFilter.video, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.video));
          }),
          _chip(l10n.mediaTabAudio, f.kind == MediaKindFilter.audio, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.audio));
          }),
          _chip(l10n.mediaTabFiles, f.kind == MediaKindFilter.file, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.file));
          }),
          const SizedBox(width: 12),
          _chip(l10n.mediaTabPinned, f.pinnedOnly, () {
            cubit.changeFilter(f.copyWith(pinnedOnly: !f.pinnedOnly));
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.state});

  final MediaGalleryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (state.status == MediaGalleryStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.blobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.mediaEmptyState,
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          busy: state.busyShas.contains(b.sha256),
          onTap: () => context.pushNamed(
            AppRoutes.mediaDetail,
            pathParameters: {'sha256': b.sha256},
          ),
          onLongPress: () => _showActions(context, b.sha256, b.pinned, b.localPath != null),
        );
      },
    );
  }

  Future<void> _showActions(
    BuildContext context,
    String sha256,
    bool pinned,
    bool cached,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<MediaGalleryCubit>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!cached)
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.mediaActionDownload),
                onTap: () {
                  Navigator.pop(ctx);
                  cubit.download(sha256);
                },
              ),
            ListTile(
              leading: Icon(pinned ? Icons.star : Icons.star_outline),
              title: Text(pinned ? l10n.mediaActionUnpin : l10n.mediaActionPin),
              onTap: () {
                Navigator.pop(ctx);
                cubit.togglePin(sha256, pinned);
              },
            ),
            if (cached)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                title: Text(l10n.mediaActionRemoveLocal,
                    style: const TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  cubit.removeLocal(sha256);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
