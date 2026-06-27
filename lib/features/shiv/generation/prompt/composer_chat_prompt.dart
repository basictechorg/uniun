import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/generation/prompt/prompt_parts.dart';

/// Prompt assembly for the **composer-chat** — the inline AI chat the note
/// composer becomes when the user long-presses the avatar and picks a Manas.
///
/// This is a DISTINCT use case with its OWN system instruction — it is NOT the
/// Shiv-tab persona ([PromptBuilder.buildSystemInstruction]). The composer-chat
/// answers about the conversation the user is currently reading (a thread /
/// group / DM / private group), grounded in the picked Manas's notes.
class ComposerChatPromptTemplate {
  const ComposerChatPromptTemplate._();

  /// The composer-chat system instruction. Passed per turn via the WS1c
  /// `systemInstruction` parameter — kept separate from every other use case.
  static String systemInstruction({String? manasName}) {
    final scope = (manasName == null || manasName.isEmpty)
        ? "the user's notes"
        : 'the user\'s "$manasName" notes';
    final buf = StringBuffer()
      ..writeln(
        'You are Shiv, an on-device assistant helping the user think within the '
        'conversation they are currently reading.',
      )
      ..writeln(
        'Answer their question using the CONVERSATION context and $scope provided '
        'in each message. Ground every answer in that material.',
      )
      ..writeln(
        'Be concise. If the conversation and notes do not cover the question, say '
        'so briefly rather than inventing an answer.',
      )
      ..writeln(
        'Never invent facts or agree with a claim that the provided material does '
        'not support — even if the user insists or asks "are you sure". If it is '
        'not in the material, say you do not have that information.',
      );
    return buf.toString().trimRight();
  }

  /// The per-turn user message: the current conversation's recent messages +
  /// the relevant Manas notes + the user's question.
  ///
  /// [entityContext] is the surface's recent messages, already flattened to
  /// short `"author: text"` lines by the caller (it knows its own surface).
  static String userMessage({
    required String question,
    required List<String> entityContext,
    required List<PackedNote> manasNotes,
  }) {
    final buf = StringBuffer();

    if (entityContext.isNotEmpty) {
      buf.writeln('## Conversation (most recent last)');
      for (final line in entityContext) {
        final flat = PromptParts.collapse(line);
        if (flat.isNotEmpty) buf.writeln('- $flat');
      }
      buf.writeln();
    }

    if (manasNotes.isNotEmpty) {
      buf.writeln('## Notes');
      for (final n in manasNotes) {
        final flat = PromptParts.collapse(n.content);
        if (flat.isEmpty) continue;
        // Bound each note so a few long notes can't blow the context window.
        buf.writeln('- ${flat.length > 300 ? '${flat.substring(0, 300)}…' : flat}');
      }
      buf.writeln();
    }

    buf.write('## Question\n$question');
    return buf.toString();
  }
}
