/// Which LLM backend currently services chat + extraction.
///
/// [localGemma] — on-device flutter_gemma inference. Default.
/// [openRouter] — cloud inference via OpenRouter (lands in Phase 3).
enum LlmBackendType {
  localGemma,
  openRouter;

  static LlmBackendType? fromName(String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
