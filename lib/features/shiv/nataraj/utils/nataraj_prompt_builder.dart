// lib/features/shiv/nataraj/utils/nataraj_prompt_builder.dart
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/generation/prompt/prompt_parts.dart';

/// Builds the one-shot prompt that asks the on-device LLM to synthesize 2-3 of
/// the user's notes into one new, coherent note. Mirrors [GanaPromptBuilder]'s
/// `/no_think` + hard-rules + NOOP discipline (shared via [PromptParts]).
class NatarajPromptBuilder {
  static const String noopSentinel = PromptParts.noopSentinel;

  static String build({required List<PackedNote> notes}) {
    final buf = StringBuffer();

    // Qwen3 soft-switch to suppress <think>…</think> chain-of-thought, which
    // would otherwise eat the token budget. Non-Qwen models ignore it.
    buf.writeln(PromptParts.noThink);

    buf
      ..writeln("You write ONE new note that synthesizes the user's own "
          "notes into a single, coherent thought.")
      ..writeln()
      ..writeln('Hard rules:')
      ..writeln('- Output ONE short paragraph, 60 words max. No preamble, no '
          'lists, no labels, no JSON, no quotes.')
      ..writeln('- Weave the ideas from the NOTES below into ONE coherent '
          'note, grounded in their actual content. Build on what they say; '
          'do not drift into unrelated tangents.')
      ..writeln('- Write plain prose the user could publish as their own note.')
      ..writeln('- If the notes share nothing meaningful, output exactly this '
          'token and nothing else: $noopSentinel')
      ..writeln();

    buf.writeln('NOTES:');
    for (final n in notes) {
      var preview = PromptParts.collapse(n.content);
      // Bound each note so the assembled prompt can't exceed the model's
      // context window (a long note otherwise overruns it → INVALID_ARGUMENT:
      // "Input token ids are too long"). ~280 chars ≈ 70 tokens per note.
      if (preview.length > 280) preview = '${preview.substring(0, 280)}…';
      buf.writeln('- $preview');
    }
    buf
      ..writeln()
      ..writeln('Now write the synthesized note in plain prose, or output '
          '$noopSentinel.');

    return buf.toString();
  }
}
