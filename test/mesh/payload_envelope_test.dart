import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/features/mesh/payload/payload_envelope.dart';

void main() {
  group('MeshMessage round-trip', () {
    test('HelloMessage with challenge + proof', () {
      final msg = HelloMessage(
        pubkey: 'a' * 64,
        challenge: 'nonce-123',
        proof: const {'id': 'deadbeef', 'sig': 'cafe', 'kind': 1},
      );
      final decoded = MeshMessage.decode(msg.encode());
      expect(decoded, isA<HelloMessage>());
      final h = decoded as HelloMessage;
      expect(h.pubkey, 'a' * 64);
      expect(h.challenge, 'nonce-123');
      expect(h.proof, {'id': 'deadbeef', 'sig': 'cafe', 'kind': 1});
    });

    test('HelloMessage opening (no proof)', () {
      final msg = HelloMessage(pubkey: 'b' * 64, challenge: 'n2');
      final h = MeshMessage.decode(msg.encode()) as HelloMessage;
      expect(h.pubkey, 'b' * 64);
      expect(h.challenge, 'n2');
      expect(h.proof, isNull);
    });

    test('EventMessage', () {
      final event = <String, dynamic>{
        'id': '1' * 64,
        'pubkey': '2' * 64,
        'created_at': 1700000000,
        'kind': 1,
        'tags': [
          ['t', 'nostr'],
        ],
        'content': 'hello mesh',
        'sig': '3' * 128,
      };
      final decoded = MeshMessage.decode(EventMessage(event).encode());
      expect(decoded, isA<EventMessage>());
      expect((decoded as EventMessage).event, event);
    });
  });

  group('MeshMessage.decode tolerance', () {
    test('garbage bytes → null', () {
      expect(MeshMessage.decode(Uint8List.fromList([0, 1, 2, 3, 255])), isNull);
    });

    test('valid JSON, unknown type → null', () {
      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode({'v': 2, 't': 'mystery'})),
      );
      expect(MeshMessage.decode(bytes), isNull);
    });

    test('wrong version → null', () {
      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode({'v': 99, 't': 'event', 'e': {}})),
      );
      expect(MeshMessage.decode(bytes), isNull);
    });

    test('non-object JSON → null', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode([1, 2, 3])));
      expect(MeshMessage.decode(bytes), isNull);
    });
  });
}
