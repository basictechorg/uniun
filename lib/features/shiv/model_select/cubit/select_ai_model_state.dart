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
    /// Which backend actually serves chats right now. Local cards only show
    /// "Active" when this is localGemma — a downloaded model is NOT active
    /// while the cloud backend is in use.
    @Default(LlmBackendType.localGemma) LlmBackendType activeBackend,
    /// True while the UNIUN Cloud sign-in runs.
    @Default(false) bool isCloudConnecting,
    /// Set when the cloud flow fails (sign-in or empty plan catalog).
    String? cloudErrorMessage,
    /// Plan-allowed cloud models, shown under the cloud card once signed in.
    @Default([]) List<LlmModelInfo> cloudModels,
    /// Cloud model currently being activated (spinner on that row).
    String? activatingCloudModelId,
    /// The cloud model in use when [activeBackend] is uniunCloud.
    String? activeCloudModelId,
  }) = _SelectAIModelState;
}
