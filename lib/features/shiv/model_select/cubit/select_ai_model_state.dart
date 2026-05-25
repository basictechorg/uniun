part of 'select_ai_model_cubit.dart';

enum SelectAIModelStatus { initial, downloading, done, error }

@freezed
abstract class SelectAIModelState with _$SelectAIModelState {
  const factory SelectAIModelState({
    @Default(SelectAIModelStatus.initial) SelectAIModelStatus status,
    @Default([]) List<AIModelEntity> models,
    /// The card the user has tapped (highlighted in UI).
    AIModelId? selectedModelId,
    /// The model that is already downloaded and active.
    AIModelId? activeModelId,
    /// All model IDs whose files are present on disk (downloaded).
    @Default({}) Set<AIModelId> downloadedModelIds,
    @Default(0.0) double downloadProgress,
    /// True while the embedding model (all-MiniLM-L6-v2) is downloading
    /// after the first LLM install. False once downloaded or already present.
    @Default(false) bool isEmbeddingDownloading,
    /// Model currently being deleted (shows spinner on that card).
    AIModelId? deletingModelId,
    String? errorMessage,
  }) = _SelectAIModelState;
}
