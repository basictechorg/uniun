import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/features/shiv/gana/engine/manas_context_loader.dart';

/// Assembles the prompt sent to the model for a single Gana run.
///
/// Structure (see `ganas.md` §2.7):
///   task → INPUT MESSAGES (with optional reply ancestry) → KNOWLEDGE
///        → tool-call instructions
///
/// Function calling is required (per plan decision #4) — all offered models
/// support the `publish_message(body)` tool. The instruction at the end
/// nudges the model toward emitting a call rather than free text.
class GanaPromptBuilder {
  /// Approximate token budget for the assembled prompt, used as a sanity
  /// guard. Per-segment budgeting is performed by the context loader.
  static const int defaultMaxTokens = 2048;

  /// [inputMessagesByOldestFirst] is in the chronological order to render
  /// (oldest first). [replyAncestry] maps `inputMsg.eventId →
  /// list_of_parents_newest_first` (empty list = no parents to show).
  static String build({
    required String taskPrompt,
    required List<String> manasNames,
    required List<PackedNote> knowledge,
    required List<NoteModel> inputMessagesByOldestFirst,
    required Map<String, List<NoteModel>> replyAncestry,
  }) {
    final buf = StringBuffer()
      ..writeln(taskPrompt.trim())
      ..writeln();

    if (inputMessagesByOldestFirst.isNotEmpty) {
      buf.writeln('INPUT MESSAGES (oldest first):');
      for (final m in inputMessagesByOldestFirst) {
        final author = _shortPubkey(m.authorPubkey);
        final when = _relativeWhen(m.created);
        final preview = m.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        buf.writeln('- @$author · $when: $preview');

        final parents = replyAncestry[m.eventId] ?? const [];
        // Render the immediate parent first; older ancestors after.
        for (final p in parents) {
          final pAuthor = _shortPubkey(p.authorPubkey);
          final pPreview =
              p.content.replaceAll(RegExp(r'\s+'), ' ').trim();
          buf.writeln('    ↳ reply context: @$pAuthor: $pPreview');
        }
      }
      buf.writeln();
    }

    if (knowledge.isNotEmpty) {
      final manasLabel = manasNames.isEmpty ? '' : manasNames.join(', ');
      buf.writeln('KNOWLEDGE (from Manas: $manasLabel):');
      for (final k in knowledge) {
        final preview = k.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        // Date only — full ISO bloats the prompt and the model rarely needs
        // millisecond precision for retrieval ranking.
        final dateStr = '${k.created.year.toString().padLeft(4, '0')}-'
            '${k.created.month.toString().padLeft(2, '0')}-'
            '${k.created.day.toString().padLeft(2, '0')}';
        buf.writeln('- [${k.id.substring(0, _idPreviewChars(k.id))}] '
            '($dateStr): $preview');
      }
      buf.writeln();
    }

    buf
      ..writeln('Respond by calling publish_message(body) with the message '
          'you want to publish.')
      ..writeln('If you have nothing meaningful to add right now, call '
          'publish_message with body="<NOOP>".');

    return buf.toString();
  }

  /// Tool schema sent alongside the prompt. Returns a JSON-Schema-like map
  /// the inference server passes through to the model's function-calling
  /// API. Keeping it minimal — body only; channel/dm/group routing is
  /// fixed by the Gana config and never model-controlled.
  static Map<String, dynamic> publishMessageTool() => const {
        'name': 'publish_message',
        'description':
            'Publish a single message to the configured output surface.',
        'parameters': {
          'type': 'object',
          'properties': {
            'body': {
              'type': 'string',
              'description': 'The message text to publish.',
            },
          },
          'required': ['body'],
        },
      };

  static String _shortPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 4)}';
  }

  static int _idPreviewChars(String id) {
    // Hex event ids → first 8 chars. UUID drafts → first 8 chars too.
    return id.length < 8 ? id.length : 8;
  }

  static String _relativeWhen(DateTime t) {
    final delta = DateTime.now().difference(t);
    if (delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    if (delta.inDays < 7) return '${delta.inDays} d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}
