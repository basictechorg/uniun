import 'dart:convert';

/// What a scanned QR represents. Drives downstream routing.
enum UniunQrKind { user, publicChannel, privateChannel }

/// Cross-feature QR payload. Encoded as JSON `{uniun, kind, id, name, relays}`.
class UniunQrPayload {
  const UniunQrPayload({
    required this.kind,
    required this.id,
    this.name,
    this.relays = const [],
  });

  /// The thing being shared:
  ///   - [UniunQrKind.user]           → npub (bech32 public key).
  ///   - [UniunQrKind.publicChannel]  → 64-char hex channel id.
  ///   - [UniunQrKind.privateChannel] → group id.
  final String id;

  /// Display label (channel name, user name). Optional.
  final String? name;

  /// Relay URLs to use when acting on this payload. Empty for user kind.
  final List<String> relays;

  final UniunQrKind kind;

  String encode() {
    return jsonEncode({
      'uniun': 1,
      'kind': switch (kind) {
        UniunQrKind.user => 'user',
        UniunQrKind.publicChannel => 'public',
        UniunQrKind.privateChannel => 'private',
      },
      'id': id,
      if (name != null) 'name': name,
      if (relays.isNotEmpty) 'relays': relays,
    });
  }

  /// Decode any QR raw value into a payload, or throw FormatException.
  ///
  /// Accepts:
  ///   1. Native envelope: `{uniun:1, kind:..., id:..., name?, relays?}`.
  ///   2. Legacy public-channel form: `{name, channel_id, relays}` (the shape
  ///      produced by the pre-unified scanner) — promoted to publicChannel.
  ///   3. Bare `nostr:npub1...` URI — promoted to user.
  ///   4. Bare `npub1...` string — promoted to user.
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

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const FormatException('QR payload is not JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR payload must be a JSON object.');
    }

    if (decoded['uniun'] != null) {
      return _fromNativeMap(decoded);
    }
    if (decoded['channel_id'] != null) {
      return _fromLegacyChannelMap(decoded);
    }
    throw const FormatException('Unrecognized QR payload.');
  }

  static UniunQrPayload _fromNativeMap(Map<String, dynamic> m) {
    final kind = switch (m['kind']) {
      'user' => UniunQrKind.user,
      'public' => UniunQrKind.publicChannel,
      'private' => UniunQrKind.privateChannel,
      _ => throw const FormatException('Unknown QR kind.'),
    };
    final id = (m['id'] as String? ?? '').trim();
    if (id.isEmpty) {
      throw const FormatException('QR id is missing.');
    }
    return UniunQrPayload(
      kind: kind,
      id: id,
      name: (m['name'] as String?)?.trim(),
      relays: _readRelays(m['relays']),
    );
  }

  static UniunQrPayload _fromLegacyChannelMap(Map<String, dynamic> m) {
    final name = (m['name'] as String? ?? '').trim();
    final channelId = (m['channel_id'] as String? ?? '').trim();
    if (channelId.isEmpty) {
      throw const FormatException('channel_id missing in QR payload.');
    }
    return UniunQrPayload(
      kind: UniunQrKind.publicChannel,
      id: channelId,
      name: name.isEmpty ? null : name,
      relays: _readRelays(m['relays']),
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
