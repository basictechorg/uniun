import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/media/media_filter.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/features/media/cubit/media_gallery_state.dart';

class MediaGalleryCubit extends Cubit<MediaGalleryState> {
  MediaGalleryCubit() : super(const MediaGalleryState());

  StreamSubscription? _sub;

  void load({MediaFilter? filter}) {
    final f = filter ?? state.filter;
    emit(state.copyWith(status: MediaGalleryStatus.loading, filter: f));
    _sub?.cancel();
    _sub = getIt<WatchMediaUseCase>().call(f).listen(
      (blobs) {
        if (isClosed) return;
        emit(state.copyWith(
          status: MediaGalleryStatus.loaded,
          blobs: blobs,
        ));
      },
      onError: (Object e) {
        if (isClosed) return;
        emit(state.copyWith(
          status: MediaGalleryStatus.error,
          errorMessage: e.toString(),
        ));
      },
    );
  }

  void changeFilter(MediaFilter filter) => load(filter: filter);

  Future<void> download(String sha256) async {
    _markBusy(sha256, true);
    final res = await getIt<DownloadMediaUseCase>().call(sha256);
    _markBusy(sha256, false);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.toMessage())),
      (_) {},
    );
  }

  Future<void> removeLocal(String sha256) async {
    _markBusy(sha256, true);
    final res = await getIt<RemoveLocalMediaUseCase>().call(sha256);
    _markBusy(sha256, false);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.toMessage())),
      (_) {},
    );
  }

  // ── Selection mode ─────────────────────────────────────────────────────

  /// Toggles [sha256] in the selection set. Empty set = selection mode off.
  void toggleSelect(String sha256) {
    final next = Set<String>.from(state.selectedShas);
    if (!next.add(sha256)) next.remove(sha256);
    emit(state.copyWith(selectedShas: next));
  }

  void clearSelection() {
    if (state.selectedShas.isEmpty) return;
    emit(state.copyWith(selectedShas: const {}));
  }

  /// Bulk "Remove from device" for every selected blob. Stops on first
  /// error; the watch stream reflects successful removals.
  Future<void> bulkRemoveLocal() async {
    final targets = state.selectedShas.toList();
    if (targets.isEmpty) return;
    final next = Set<String>.from(state.busyShas)..addAll(targets);
    emit(state.copyWith(busyShas: next));
    String? err;
    for (final sha in targets) {
      final res = await getIt<RemoveLocalMediaUseCase>().call(sha);
      res.fold((f) => err = f.toMessage(), (_) {});
      if (err != null) break;
    }
    final cleared = Set<String>.from(state.busyShas)..removeAll(targets);
    emit(state.copyWith(
      busyShas: cleared,
      selectedShas: const {},
      errorMessage: err,
    ));
  }

  void _markBusy(String sha256, bool busy) {
    final next = Set<String>.from(state.busyShas);
    if (busy) {
      next.add(sha256);
    } else {
      next.remove(sha256);
    }
    emit(state.copyWith(busyShas: next));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
