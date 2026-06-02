import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';

/// Static map from our public [AIModelId] to the flutter_gemma engine params
/// the chat session needs.
///
/// `openChat` defaults `modelType` to [ModelType.gemmaIt]; if we don't override
/// it the SDK renders the wrong chat template (leading whitespace, missing
/// turn separators, sometimes degraded answers).
///
/// Duplicates the table in `AIModelRepositoryImpl` intentionally — that one
/// is for the download/install path, this one is for the runtime path. They
/// must stay in sync; if they drift, the engine + template will mismatch.
class LocalModelParams {
  const LocalModelParams({
    required this.modelType,
    required this.isThinking,
  });

  final ModelType modelType;
  final bool isThinking;

  static LocalModelParams? forId(AIModelId? id) {
    if (id == null) return null;
    switch (id) {
      case AIModelId.qwen25_05b:
        return const LocalModelParams(
          modelType: ModelType.qwen3,
          isThinking: false,
        );
      case AIModelId.deepseekR1:
        return const LocalModelParams(
          modelType: ModelType.deepSeek,
          isThinking: true,
        );
      case AIModelId.gemma4E2b:
      case AIModelId.gemma4E4b:
        return const LocalModelParams(
          modelType: ModelType.gemma4,
          isThinking: false,
        );
    }
  }
}
