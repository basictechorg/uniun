import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/gateway/session/nostr_frame.dart';

/// Covers: NostrFrame's REQ/CLOSE wire encoding, and decodeFrame's full
/// dispatch table (EVENT/OK/EOSE/NOTICE/unknown-type) including every
/// malformed-shape rejection (unparseable JSON, empty array, too-short
/// arrays, wrong field types) that must return null or InboundUnknown
/// rather than throw.
void main() {
  group('NostrFrame', () {
    test('req encodes a REQ frame with subId and filter', () {
      final frame = NostrFrame.req('sub1', {'kinds': [1]});
      expect(jsonDecode(frame), ['REQ', 'sub1', {'kinds': [1]}]);
    });

    test('close encodes a CLOSE frame', () {
      final frame = NostrFrame.close('sub1');
      expect(jsonDecode(frame), ['CLOSE', 'sub1']);
    });
  });

  group('decodeFrame', () {
    test('unparseable JSON returns null', () {
      expect(decodeFrame('not-json'), isNull);
    });

    test('a non-list top-level value returns null (cast failure caught)',
        () {
      expect(decodeFrame('{"a":1}'), isNull);
    });

    test('an empty array returns null', () {
      expect(decodeFrame('[]'), isNull);
    });

    test('a type-less first element falls through to InboundUnknown', () {
      expect(decodeFrame('[123]'), isA<InboundUnknown>());
    });

    group('EVENT', () {
      test('decodes a well-formed EVENT frame', () {
        final msg = decodeFrame(jsonEncode(['EVENT', 'sub1', {'id': 'e1'}]));
        expect(msg, isA<InboundEvent>());
        final ev = msg as InboundEvent;
        expect(ev.subId, 'sub1');
        expect(ev.event, {'id': 'e1'});
      });

      test('too few elements returns null', () {
        expect(decodeFrame(jsonEncode(['EVENT', 'sub1'])), isNull);
      });

      test('a non-string subId returns null', () {
        expect(decodeFrame(jsonEncode(['EVENT', 1, {'id': 'e1'}])), isNull);
      });

      test('a non-map event payload returns null', () {
        expect(decodeFrame(jsonEncode(['EVENT', 'sub1', 'not-a-map'])), isNull);
      });
    });

    group('OK', () {
      test('decodes a well-formed OK frame', () {
        final msg = decodeFrame(jsonEncode(['OK', 'evt-1', true]));
        expect(msg, isA<InboundOk>());
        final ok = msg as InboundOk;
        expect(ok.eventId, 'evt-1');
        expect(ok.accepted, isTrue);
      });

      test('too few elements returns null', () {
        expect(decodeFrame(jsonEncode(['OK', 'evt-1'])), isNull);
      });

      test('a non-string eventId returns null', () {
        expect(decodeFrame(jsonEncode(['OK', 1, true])), isNull);
      });

      test('a non-bool accepted flag returns null', () {
        expect(decodeFrame(jsonEncode(['OK', 'evt-1', 'yes'])), isNull);
      });
    });

    group('EOSE', () {
      test('decodes a well-formed EOSE frame', () {
        final msg = decodeFrame(jsonEncode(['EOSE', 'sub1']));
        expect(msg, isA<InboundEose>());
        expect((msg as InboundEose).subId, 'sub1');
      });

      test('too few elements returns null', () {
        expect(decodeFrame(jsonEncode(['EOSE'])), isNull);
      });

      test('a non-string subId returns null', () {
        expect(decodeFrame(jsonEncode(['EOSE', 1])), isNull);
      });
    });

    group('NOTICE', () {
      test('decodes a message payload', () {
        final msg = decodeFrame(jsonEncode(['NOTICE', 'rate limited']));
        expect(msg, isA<InboundNotice>());
        expect((msg as InboundNotice).message, 'rate limited');
      });

      test('a missing message payload becomes an empty string', () {
        final msg = decodeFrame(jsonEncode(['NOTICE']));
        expect((msg as InboundNotice).message, '');
      });
    });

    test('an unrecognized type falls through to InboundUnknown', () {
      expect(decodeFrame(jsonEncode(['CLOSED', 'sub1'])), isA<InboundUnknown>());
    });
  });
}
