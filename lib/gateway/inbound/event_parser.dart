/// Map-walking helpers shared by all [KindHandler]s.
///
/// Avoid duplicating the tag-walking and field-extraction boilerplate across
/// every handler — these are pure functions over the raw Nostr event map.
class EventParser {
  EventParser._();

  /// Extracts all `e` tag event IDs from an event map (no marker filter).
  static List<String> eTagIds(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? []);
    final out = <String>[];
    for (final rawTag in rawTags) {
      if (rawTag is! List || rawTag.length < 2) continue;
      if (rawTag[0] != 'e') continue;
      final id = rawTag[1] as String?;
      if (id == null || id.isEmpty) continue;
      out.add(id);
    }
    return out;
  }

  /// Returns the value of the first tag matching [name], or null.
  static String? firstTagValue(Map<String, dynamic> event, String name) {
    final rawTags = (event['tags'] as List<dynamic>? ?? []);
    for (final rawTag in rawTags) {
      if (rawTag is List && rawTag.length >= 2 && rawTag[0] == name) {
        return rawTag[1] as String?;
      }
    }
    return null;
  }

  /// Converts a Nostr `created_at` (unix seconds) to [DateTime].
  static DateTime dateTimeFromSec(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000);
}
