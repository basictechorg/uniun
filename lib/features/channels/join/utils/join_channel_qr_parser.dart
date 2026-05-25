import 'dart:convert';

class JoinChannelQrPayload {
  const JoinChannelQrPayload({
    required this.channelName,
    required this.channelId,
    required this.relays,
  });
  final String channelName;
  final String channelId;
  final List<String> relays;
}

class JoinChannelQrParser {
  const JoinChannelQrParser._();

  static JoinChannelQrPayload parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid QR payload.');
    }

    final channelName = (decoded['name'] as String? ?? '').trim();
    if (channelName.isEmpty) {
      throw const FormatException('Channel name missing in QR payload.');
    }

    final channelId = (decoded['channel_id'] as String? ?? '').trim();
    if (!_isHex64(channelId)) {
      throw const FormatException('Invalid channel id in QR payload.');
    }

    final relaysRaw = decoded['relays'];
    if (relaysRaw is! List) {
      throw const FormatException('QR payload relays must be a list.');
    }

    final relays = relaysRaw
        .map((relay) => relay.toString().trim())
        .where((relay) => relay.isNotEmpty)
        .toSet()
        .toList();

    if (relays.isEmpty) {
      throw const FormatException('Invalid relay list in QR payload.');
    }

    return JoinChannelQrPayload(
      channelName: channelName,
      channelId: channelId,
      relays: relays,
    );
  }

  static bool isValidChannelId(String channelId) {
    return _isHex64(channelId.trim());
  }

  static bool _isHex64(String value) {
    final hexPattern = RegExp(r'^[0-9a-fA-F]{64}$');
    return hexPattern.hasMatch(value);
  }
}
