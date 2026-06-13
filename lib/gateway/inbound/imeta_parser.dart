import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/media/media_blob_model.dart';
import 'package:uniun/data/models/media/note_media_ref_model.dart';

/// One parsed `imeta` tag (NIP-92).
///
/// Each Kind 1/42 event can carry many `imeta` tags — one per attached blob.
/// The first space-separated token of each sub-string is the key, the rest
/// is the value. We only capture the fields we render or persist.
class ImetaTag {
  const ImetaTag({
    required this.url,
    required this.sha256,
    required this.mime,
    this.sizeBytes,
    this.width,
    this.height,
    this.blurhash,
    this.filename,
  });

  final String url;
  final String sha256;
  final String mime;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final String? blurhash;
  final String? filename;
}

class ImetaParser {
  ImetaParser._();

  /// Fast pre-check used by inbound handlers to set [NoteModel.hasMedia]
  /// without fully parsing every tag. Stops at the first `imeta` tag.
  static bool hasImeta(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? const []);
    for (final raw in rawTags) {
      if (raw is List && raw.isNotEmpty && raw[0] == 'imeta') return true;
    }
    return false;
  }

  /// Walks an event's `tags` array and returns every well-formed `imeta`.
  /// Drops malformed tags silently — a partial blob can't be rendered
  /// anyway, and noisy logging on the inbound hot path is worse than the
  /// occasional missing attachment.
  static List<ImetaTag> parse(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? const []);
    final out = <ImetaTag>[];
    for (final raw in rawTags) {
      if (raw is! List || raw.isEmpty) continue;
      if (raw[0] != 'imeta') continue;
      final tag = _parseOne(raw);
      if (tag != null) out.add(tag);
    }
    return out;
  }

  static ImetaTag? _parseOne(List rawTag) {
    String? url;
    String? sha256;
    String? mime;
    int? sizeBytes;
    int? width;
    int? height;
    String? blurhash;
    String? filename;

    for (var i = 1; i < rawTag.length; i++) {
      final entry = rawTag[i];
      if (entry is! String) continue;
      final space = entry.indexOf(' ');
      if (space <= 0) continue;
      final key = entry.substring(0, space);
      final value = entry.substring(space + 1).trim();
      if (value.isEmpty) continue;
      switch (key) {
        case 'url':
          url = value;
        case 'x':
          sha256 = value;
        case 'm':
          mime = value;
        case 'size':
          sizeBytes = int.tryParse(value);
        case 'dim':
          final parts = value.split('x');
          if (parts.length == 2) {
            width = int.tryParse(parts[0]);
            height = int.tryParse(parts[1]);
          }
        case 'blurhash':
          blurhash = value;
        case 'name':
          filename = value;
      }
    }

    if (url == null || sha256 == null) return null;
    return ImetaTag(
      url: url,
      sha256: sha256,
      mime: mime ?? 'application/octet-stream',
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      blurhash: blurhash,
      filename: filename,
    );
  }

  /// Persists every imeta tag on [event] into [MediaBlobModel] (upsert by
  /// sha256) and writes a [NoteMediaRefModel] row linking the note. Must run
  /// inside the caller's `writeTxn`. Inbound rows leave `localPath` null —
  /// the user explicitly downloads from the gallery / note card.
  static Future<void> persistInTxn({
    required Isar isar,
    required String noteEventId,
    required Map<String, dynamic> event,
  }) async {
    final imetas = parse(event);
    if (imetas.isEmpty) return;
    final now = DateTime.now();
    for (final m in imetas) {
      final existing = await isar.mediaBlobModels
          .filter()
          .sha256EqualTo(m.sha256)
          .findFirst();
      final row = existing ?? MediaBlobModel();
      row.sha256 = m.sha256;
      row.mime = m.mime;
      row.sizeBytes = m.sizeBytes ?? existing?.sizeBytes ?? 0;
      row.width = m.width ?? existing?.width;
      row.height = m.height ?? existing?.height;
      row.blurhash = m.blurhash ?? existing?.blurhash;
      row.filename = m.filename ?? existing?.filename;
      final urls = <String>{...(existing?.serverUrls ?? const []), m.url};
      row.serverUrls = urls.toList();
      // localPath / downloadedAt left untouched — bytes are user-fetched.
      row.lastSeenAt = now;
      row.pinned = existing?.pinned ?? false;
      await isar.mediaBlobModels.put(row);

      final refExists = await isar.noteMediaRefModels
          .filter()
          .noteEventIdEqualTo(noteEventId)
          .mediaSha256EqualTo(m.sha256)
          .findFirst();
      if (refExists == null) {
        await isar.noteMediaRefModels.put(
          NoteMediaRefModel()
            ..noteEventId = noteEventId
            ..mediaSha256 = m.sha256,
        );
      }
    }
  }
}
