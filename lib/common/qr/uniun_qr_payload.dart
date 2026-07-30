import 'dart:convert';

/// What a scanned QR represents. Drives downstream routing.
enum UniunQrKind { user, publicGroup, privateGroup, loginSession }

/// Cross-feature QR payload. Encoded as JSON `{kind, id, name?, relays?}`.
class UniunQrPayload {
  const UniunQrPayload({
    required this.kind,
    required this.id,
    this.name,
    this.relays = const [],
  });

  /// The thing being shared:
  ///   - [UniunQrKind.user]           → npub (bech32 public key).
  ///   - [UniunQrKind.publicGroup]  → 64-char hex group id.
  ///   - [UniunQrKind.privateGroup] → group id.
  ///   - [UniunQrKind.loginSession] → the gateway's QR-login `session_id`.
  final String id;

  /// Display label (group name, user name). Optional.
  final String? name;

  /// Relay URLs to use when acting on this payload. Empty for user kind.
  final List<String> relays;

  final UniunQrKind kind;

  String encode() {
    return jsonEncode({
      'kind': switch (kind) {
        UniunQrKind.user => 'user',
        UniunQrKind.publicGroup => 'public',
        UniunQrKind.privateGroup => 'private',
        UniunQrKind.loginSession => 'login',
      },
      'id': id,
      if (name != null) 'name': name,
      if (relays.isNotEmpty) 'relays': relays,
    });
  }

  /// Decode any QR raw value into a payload, or throw FormatException.
  ///
  /// Accepts:
  ///   1. JSON object `{kind, id, name?, relays?}`.
  ///   2. Bare `nostr:npub1...` or `npub1...` string — promoted to user kind.
  ///   3. `uniun://qr-login?s=<session_id>` — the gateway's web QR-login URI
  ///      (`docs/frontend/QR-LOGIN.md`) — promoted to [UniunQrKind.loginSession].
  static UniunQrPayload decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty QR payload.');
    }

    if (trimmed.startsWith('nostr:npub1') || trimmed.startsWith('npub1')) {
      final npub = trimmed.startsWith('nostr:')
          ? trimmed.substring('nostr:'.length)
          : trimmed;
      return UniunQrPayload(kind: UniunQrKind.user, id: npub);
    }

    if (trimmed.toLowerCase().startsWith('uniun://qr-login')) {
      final uri = Uri.tryParse(trimmed);
      final sessionId = uri?.queryParameters['s']?.trim();
      if (sessionId == null || sessionId.isEmpty) {
        throw const FormatException('QR login link is missing a session id.');
      }
      return UniunQrPayload(kind: UniunQrKind.loginSession, id: sessionId);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const FormatException('QR payload is not JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR payload must be a JSON object.');
    }

    final kind = switch (decoded['kind']) {
      'user' => UniunQrKind.user,
      'public' => UniunQrKind.publicGroup,
      'private' => UniunQrKind.privateGroup,
      'login' => UniunQrKind.loginSession,
      _ => throw const FormatException('Unknown QR kind.'),
    };
    final id = (decoded['id'] as String? ?? '').trim();
    if (id.isEmpty) {
      throw const FormatException('QR id is missing.');
    }
    return UniunQrPayload(
      kind: kind,
      id: id,
      name: (decoded['name'] as String?)?.trim(),
      relays: _readRelays(decoded['relays']),
    );
  }

  static List<String> _readRelays(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((r) => r.toString().trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
  }
}
