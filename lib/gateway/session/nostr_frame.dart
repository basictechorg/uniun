import 'dart:convert';

/// Helpers to build NIP-01 wire frames.
class NostrFrame {
  NostrFrame._();

  static String req(String subId, Map<String, dynamic> filter) =>
      jsonEncode(['REQ', subId, filter]);

  static String close(String subId) => jsonEncode(['CLOSE', subId]);
}

/// Parsed inbound message types.
sealed class InboundMessage {
  const InboundMessage();
}

class InboundEvent extends InboundMessage {
  final String subId;
  final Map<String, dynamic> event;
  const InboundEvent(this.subId, this.event);
}

class InboundOk extends InboundMessage {
  final String eventId;
  final bool accepted;
  const InboundOk(this.eventId, this.accepted);
}

class InboundEose extends InboundMessage {
  final String subId;
  const InboundEose(this.subId);
}

class InboundNotice extends InboundMessage {
  final String message;
  const InboundNotice(this.message);
}

class InboundUnknown extends InboundMessage {
  const InboundUnknown();
}

InboundMessage? decodeFrame(String raw) {
  List<dynamic> data;
  try {
    data = jsonDecode(raw) as List<dynamic>;
  } catch (_) {
    return null;
  }
  if (data.isEmpty) return null;
  final type = data[0] as String?;
  switch (type) {
    case 'EVENT':
      if (data.length < 3) return null;
      return InboundEvent(data[1] as String, data[2] as Map<String, dynamic>);
    case 'OK':
      if (data.length < 3) return null;
      return InboundOk(data[1] as String, data[2] as bool? ?? false);
    case 'EOSE':
      if (data.length < 2) return null;
      return InboundEose(data[1] as String);
    case 'NOTICE':
      return InboundNotice(data.length > 1 ? '${data[1]}' : '');
    default:
      return const InboundUnknown();
  }
}
