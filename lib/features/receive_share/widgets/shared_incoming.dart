import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Normalized view of an inbound OS share for the receive-share sheet.
///
/// Presentation-layer transfer object (NOT a domain entity — it carries the
/// `receive_sharing_intent` [SharedMediaType]). Splits a raw batch into the
/// text that pre-fills the composer and the media files to ingest + upload.
class SharedIncoming {
  const SharedIncoming({required this.text, required this.files});

  /// Joined text/URL content (+ any media captions), or null when none.
  final String? text;

  /// Image / video / arbitrary-file entries to read, compress, and upload.
  final List<SharedMediaFile> files;

  bool get isEmpty => (text == null || text!.isEmpty) && files.isEmpty;

  /// Builds a [SharedIncoming] from a raw `receive_sharing_intent` batch.
  ///
  /// For `text`/`url` entries the shared string rides in [SharedMediaFile.path]
  /// (not a filesystem path). Any [SharedMediaFile.message] caption is appended
  /// to the text so a "photo + caption" share keeps the caption.
  factory SharedIncoming.fromFiles(List<SharedMediaFile> list) {
    final textBits = <String>[];
    final media = <SharedMediaFile>[];
    for (final f in list) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        if (f.path.isNotEmpty) textBits.add(f.path);
      } else {
        media.add(f);
      }
      final caption = f.message;
      if (caption != null && caption.isNotEmpty) textBits.add(caption);
    }
    return SharedIncoming(
      text: textBits.isEmpty ? null : textBits.join('\n'),
      files: media,
    );
  }
}
