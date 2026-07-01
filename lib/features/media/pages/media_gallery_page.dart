import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/router/app_routes.dart';
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: const _GalleryAppBar(),
      body: BlocBuilder<MediaGalleryCubit, MediaGalleryState>(
        builder: (context, state) {
          return Column(
            children: [
              if (!state.isSelecting) _FilterStrip(state: state),
              Expanded(child: _Grid(state: state)),
            ],
          );
        },
      ),
    );
  }
}

/// Two-mode app bar: normal (title only) and selection (count + bulk
/// remove). Bulk remove is enabled only when at least one selected blob is
/// cached locally — removing a remote-only row is a no-op.
class _GalleryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _GalleryAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MediaGalleryCubit, MediaGalleryState>(
      buildWhen: (a, b) =>
          a.isSelecting != b.isSelecting ||
          a.selectedShas.length != b.selectedShas.length,
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final cubit = context.read<MediaGalleryCubit>();

        if (!state.isSelecting) {
          return AppBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            elevation: 0,
            leading: const UniunBackButton(),
            title: Text(l10n.mediaGalleryTitle),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          );
        }

        final selectedBlobs = state.blobs
            .where((b) => state.selectedShas.contains(b.sha256))
            .toList();
        final anyCached =
            selectedBlobs.any((b) => b.localPath != null);

        return AppBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          elevation: 0,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.mediaSelectionExit,
            onPressed: cubit.clearSelection,
          ),
          title: Text(
            l10n.mediaSelectionCount(state.selectedShas.length),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error),
              tooltip: l10n.mediaActionRemoveLocal,
              onPressed: anyCached
                  ? () => _confirmBulkRemove(
                        context,
                        cubit,
                        l10n,
                        state.selectedShas.length,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmBulkRemove(
    BuildContext context,
    MediaGalleryCubit cubit,
    AppLocalizations l10n,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        title: Text(l10n.mediaSelectionRemoveDialogTitle),
        content: Text(l10n.mediaSelectionRemoveDialogBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(l10n.actionCancel,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(
              l10n.mediaActionRemoveLocal,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) cubit.bulkRemoveLocal();
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
          _chip(context, l10n.mediaTabAll, f.kind == MediaKindFilter.all, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.all));
          }),
          _chip(context, l10n.mediaTabImages, f.kind == MediaKindFilter.image, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.image));
          }),
          _chip(context, l10n.mediaTabVideos, f.kind == MediaKindFilter.video, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.video));
          }),
          _chip(context, l10n.mediaTabAudio, f.kind == MediaKindFilter.audio, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.audio));
          }),
          _chip(context, l10n.mediaTabFiles, f.kind == MediaKindFilter.file, () {
            cubit.changeFilter(f.copyWith(kind: MediaKindFilter.file));
          }),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected,
      VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
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
      return Center(
        child: DropLoadingIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }
    if (state.blobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.mediaEmptyState,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        final selected = state.selectedShas.contains(b.sha256);
        final selecting = state.isSelecting;
        final cubit = context.read<MediaGalleryCubit>();
        return MediaTile(
          key: ValueKey(b.sha256),
          blob: b,
          busy: state.busyShas.contains(b.sha256),
          selected: selected,
          // Selection mode: tap toggles. Normal mode: tap opens detail.
          onTap: () {
            if (selecting) {
              cubit.toggleSelect(b.sha256);
              return;
            }
            context.pushNamed(
              AppRoutes.mediaDetail,
              pathParameters: {'sha256': b.sha256},
            );
          },
          onLongPress: () => cubit.toggleSelect(b.sha256),
        );
      },
    );
  }

  // Per-blob actions live on MediaDetailPage; long-press in the grid
  // enters multi-select.
}
