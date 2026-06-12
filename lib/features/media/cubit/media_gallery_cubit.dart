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

  Future<void> togglePin(String sha256, bool currentlyPinned) async {
    _markBusy(sha256, true);
    final res = currentlyPinned
        ? await getIt<UnpinMediaUseCase>().call(sha256)
        : await getIt<PinMediaUseCase>().call(sha256);
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
