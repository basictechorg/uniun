import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/repositories/media_repository.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';

class MediaDetailState {
  const MediaDetailState({
    this.blob,
    this.busy = false,
    this.errorMessage,
  });

  final MediaBlobEntity? blob;
  final bool busy;
  final String? errorMessage;

  MediaDetailState copyWith({
    MediaBlobEntity? blob,
    bool? busy,
    String? errorMessage,
  }) =>
      MediaDetailState(
        blob: blob ?? this.blob,
        busy: busy ?? this.busy,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class MediaDetailCubit extends Cubit<MediaDetailState> {
  MediaDetailCubit({required this.sha256}) : super(const MediaDetailState());

  final String sha256;
  StreamSubscription? _sub;

  Future<void> load() async {
    // Entered from the gallery, which only lists cached blobs — so the
    // cache row exists and carries the local path. Imeta metadata is in
    // the first NoteModel that referenced it (joined by the repo).
    final res = await getIt<MediaRepository>().getCachedBySha(sha256);
    res.fold(
      (f) => emit(state.copyWith(errorMessage: f.toMessage())),
      (b) {
        if (b != null) emit(state.copyWith(blob: b));
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
