/// Shared building blocks for the on-device LLM prompts used by the autonomous
/// generators (Gana, Nataraj). Keeps the small-but-easy-to-drift conventions —
/// the Qwen `/no_think` switch, the `<NOOP>` skip sentinel, and note-content
/// normalisation — in ONE place so the two builders can't diverge.
///
/// The interactive chat [PromptBuilder] is intentionally NOT built on this: it
/// is budget-aware and sectioned, a structurally different prompt, and uses the
/// model's native `isThinking` flag rather than the `/no_think` directive.
class PromptParts {
  const PromptParts._();

  /// Qwen3's official soft-switch to disable chain-of-thought. Without it Qwen
  /// wraps answers in `<think>…</think>`; if maxTokens runs out mid-thought we
  /// get no answer at all. Non-Qwen models ignore unknown directives at the top.
  static const String noThink = '/no_think';

  /// Output sentinel — the model emits this exact string (case-insensitive,
  /// trimmed) when it has nothing meaningful to add; the engine treats it as a
  /// skip and advances.
  static const String noopSentinel = '<NOOP>';

  /// Collapse every run of whitespace to a single space and trim. Used to
  /// flatten note content onto a single prompt line.
  static String collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// `YYYY-MM-DD` for prompt date stamps.
  static String isoDate(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}
