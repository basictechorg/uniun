import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';

class MediaDetailState {
  const MediaDetailState({
    this.blob,
    this.referencingNoteIds = const [],
    this.busy = false,
    this.errorMessage,
  });

  final MediaBlobEntity? blob;
  final List<String> referencingNoteIds;
  final bool busy;
  final String? errorMessage;

  MediaDetailState copyWith({
    MediaBlobEntity? blob,
    List<String>? referencingNoteIds,
    bool? busy,
    String? errorMessage,
  }) =>
      MediaDetailState(
        blob: blob ?? this.blob,
        referencingNoteIds: referencingNoteIds ?? this.referencingNoteIds,
        busy: busy ?? this.busy,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class MediaDetailCubit extends Cubit<MediaDetailState> {
  MediaDetailCubit({required this.sha256}) : super(const MediaDetailState());

  final String sha256;
  StreamSubscription? _sub;

  Future<void> load() async {
    final blobRes = await getIt<GetMediaUseCase>().call(sha256);
    blobRes.fold(
      (f) => emit(state.copyWith(errorMessage: f.toMessage())),
      (b) => emit(state.copyWith(blob: b)),
    );
    final refRes = await getIt<GetReferencingNoteIdsUseCase>().call(sha256);
    refRes.fold(
      (_) {},
      (ids) => emit(state.copyWith(referencingNoteIds: ids)),
    );
  }

  Future<void> download() async {
    emit(state.copyWith(busy: true));
    final res = await getIt<DownloadMediaUseCase>().call(sha256);
    res.fold(
      (f) => emit(state.copyWith(busy: false, errorMessage: f.toMessage())),
      (b) => emit(state.copyWith(busy: false, blob: b)),
    );
  }

  Future<void> togglePin() async {
    final pinned = state.blob?.pinned ?? false;
    emit(state.copyWith(busy: true));
    final res = pinned
        ? await getIt<UnpinMediaUseCase>().call(sha256)
        : await getIt<PinMediaUseCase>().call(sha256);
    res.fold(
      (f) => emit(state.copyWith(busy: false, errorMessage: f.toMessage())),
      (_) async {
        await load();
        emit(state.copyWith(busy: false));
      },
    );
  }

  Future<void> removeLocal() async {
    emit(state.copyWith(busy: true));
    final res = await getIt<RemoveLocalMediaUseCase>().call(sha256);
    res.fold(
      (f) => emit(state.copyWith(busy: false, errorMessage: f.toMessage())),
      (_) async {
        await load();
        emit(state.copyWith(busy: false));
      },
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
