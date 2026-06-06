import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/services/download_cancellation.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/features/shiv/rag/embedding/embedding_model_downloader.dart';

part 'select_ai_model_state.dart';
part 'select_ai_model_cubit.freezed.dart';

@injectable
class SelectAIModelCubit extends Cubit<SelectAIModelState> {
  final GetAvailableAIModelsUseCase _getAvailable;
  final GetActiveAIModelUseCase _getActive;
  final GetDownloadedModelIdsUseCase _getDownloaded;
  final DownloadAndActivateAIModelUseCase _download;
  final DeleteAIModelUseCase _deleteModel;
  final EmbeddingModelDownloader _embeddingDownloader;

  StreamSubscription<AIModelDownloadEvent>? _downloadSub;
  DownloadCancellation? _cancellation;

  SelectAIModelCubit(
    this._getAvailable,
    this._getActive,
    this._getDownloaded,
    this._download,
    this._deleteModel,
    this._embeddingDownloader,
  ) : super(const SelectAIModelState()) {
    _init();
  }

  Future<void> _init() async {
    final models = await _getAvailable.call();
    final activeResult = await _getActive.call();
    final activeId = activeResult.fold((_) => null, (m) => m?.modelId);
    final downloadedIds = await _getDownloaded.call();

    emit(state.copyWith(
      models: models,
      activeModelId: activeId,
      downloadedModelIds: downloadedIds,
      selectedModelId: activeId ??
          models.where((m) => m.isRecommended).firstOrNull?.modelId ??
          models.firstOrNull?.modelId,
    ));

    // If a model is already active (app restart with existing model),
    // ensure the embedding model files are also present.
    if (activeId != null) {
      unawaited(_ensureEmbeddingDownloaded());
    }
  }

  Future<void> _ensureEmbeddingDownloaded() async {
    if (await _embeddingDownloader.isDownloaded()) return;
    if (isClosed) return;
    emit(state.copyWith(isEmbeddingDownloading: true));
    await _embeddingDownloader.downloadIfNeeded();
    if (isClosed) return;
    emit(state.copyWith(isEmbeddingDownloading: false));
  }

  Future<void> refresh() => _init();

  void selectModel(AIModelId modelId) {
    if (state.status == SelectAIModelStatus.downloading) return;
    emit(state.copyWith(selectedModelId: modelId));
  }

  Future<void> downloadAndActivate() async {
    final modelId = state.selectedModelId;
    if (modelId == null) return;
    if (state.status == SelectAIModelStatus.downloading) return;

    if (modelId == state.activeModelId) {
      emit(state.copyWith(status: SelectAIModelStatus.done));
      return;
    }

    emit(state.copyWith(
      status: SelectAIModelStatus.downloading,
      downloadProgress: 0.0,
      errorMessage: null,
    ));

    _downloadSub?.cancel();
    _cancellation = DownloadCancellation();
    _downloadSub = _download.call(modelId, cancellation: _cancellation).listen(
      (event) {
        event.when(
          progress: (value) =>
              emit(state.copyWith(downloadProgress: value)),
          complete: (id) async {
            // Download embedding model BEFORE emitting done, so the cubit
            // is still alive (navigating away on done closes the cubit).
            if (!await _embeddingDownloader.isDownloaded()) {
              if (isClosed) return;
              emit(state.copyWith(
                downloadProgress: 1.0,
                isEmbeddingDownloading: true,
              ));
              await _embeddingDownloader.downloadIfNeeded();
              if (isClosed) return;
              // Embedding download complete — clear embedding flag
              emit(state.copyWith(
                isEmbeddingDownloading: false,
                downloadProgress: 1.0,
              ));
            }
            if (isClosed) return;
            // All downloads complete — emit done status
            emit(state.copyWith(
              status: SelectAIModelStatus.done,
              activeModelId: id,
              downloadProgress: 1.0,
              isEmbeddingDownloading: false,
            ));
          },
          failed: (msg) => emit(state.copyWith(
            status: SelectAIModelStatus.error,
            errorMessage: msg,
          )),
        );
      },
      onError: (e) => emit(state.copyWith(
        status: SelectAIModelStatus.error,
        errorMessage: e.toString(),
      )),
    );
  }

  Future<void> cancelDownload() async {
    if (state.status != SelectAIModelStatus.downloading) return;

    _cancellation?.cancel();
    _cancellation = null;
    await _downloadSub?.cancel();
    _downloadSub = null;

    if (isClosed) return;
    emit(state.copyWith(
      status: SelectAIModelStatus.initial,
      downloadProgress: 0.0,
      errorMessage: null,
    ));
  }

  Future<void> deleteModel(AIModelId modelId) async {
    if (state.deletingModelId != null) return;
    emit(state.copyWith(deletingModelId: modelId));
    final result = await _deleteModel.call(modelId);
    result.fold(
      (f) => emit(state.copyWith(
        deletingModelId: null,
        errorMessage: f.toString(),
      )),
      (_) async {
        final downloadedIds = await _getDownloaded.call();
        final activeId = state.activeModelId == modelId ? null : state.activeModelId;
        emit(state.copyWith(
          deletingModelId: null,
          downloadedModelIds: downloadedIds,
          activeModelId: activeId,
          // If we deleted the selected model, fall back to first available.
          selectedModelId: state.selectedModelId == modelId
              ? (state.models.firstOrNull?.modelId)
              : state.selectedModelId,
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _cancellation?.cancel();
    _downloadSub?.cancel();
    return super.close();
  }
}
