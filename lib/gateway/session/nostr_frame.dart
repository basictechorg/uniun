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
  final rawType = data[0];
  final type = rawType is String ? rawType : null;
  switch (type) {
    case 'EVENT':
      if (data.length < 3) return null;
      final subId = data[1];
      final event = data[2];
      if (subId is! String || event is! Map) return null;
      return InboundEvent(subId, Map<String, dynamic>.from(event));
    case 'OK':
      if (data.length < 3) return null;
      final eventId = data[1];
      final accepted = data[2];
      if (eventId is! String || accepted is! bool) return null;
      return InboundOk(eventId, accepted);
    case 'EOSE':
      if (data.length < 2) return null;
      final subId = data[1];
      if (subId is! String) return null;
      return InboundEose(subId);
    case 'NOTICE':
      return InboundNotice(data.length > 1 ? '${data[1]}' : '');
    default:
      return const InboundUnknown();
  }
}
