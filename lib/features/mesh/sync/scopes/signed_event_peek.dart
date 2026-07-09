import 'dart:convert';

/// Cheap `id` + `created_at` peek off a stored `signedNostrEvent` JSON
/// string, without paying the codec/decrypt cost. Every negentropy scope
/// needs this on both the `localIndex()` (rebuild the id→ts map) and the
/// LWW compare on write (`upsertSigned`).
///
/// Returns `null` when the payload is missing, malformed, or lacks a
/// well-formed 64-char id + numeric created_at.
class SignedEventPeek {
  const SignedEventPeek._(this.id, this.createdAt);

  final String id;
  final int createdAt;

  /// Best-effort parse. Skips any structural nastiness — a bad row simply
  /// falls out of negentropy (the next write will regenerate a well-formed
  /// event).
  static SignedEventPeek? tryPeek(String signedJson) {
    try {
      final j = jsonDecode(signedJson);
      if (j is! Map<String, dynamic>) return null;
      final id = j['id'];
      final createdAt = j['created_at'];
      if (id is String && id.length == 64 && createdAt is num) {
        return SignedEventPeek._(id, createdAt.toInt());
      }
    } catch (_) {}
    return null;
  }
}
