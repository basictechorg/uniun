import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http_;
import 'package:http/testing.dart';
import 'package:uniun/data/datasources/blossom_client.dart';

import '../../_helpers/fixtures.dart';

/// Covers: BlobDescriptor.fromJson wire-format contract AND every HTTP
/// method on BlossomClient — head, upload (with all status branches),
/// download / downloadFromUrl (with wss/ws scheme coerce), list, deleteRemote,
/// and _buildAuth's Kind-24242 shape via the Authorization header.
void main() {
  const testKeys = kSigningKeys;


  group('BlobDescriptor.fromJson — happy path', () {
    test('maps url / sha256 / size / mime / uploaded', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(
        url: 'https://s/x.jpg',
        sha256: 'sha',
        size: 42,
        type: 'image/png',
        uploaded: 1000000,
      ));
      expect(d.url, 'https://s/x.jpg');
      expect(d.sha256, 'sha');
      expect(d.size, 42);
      expect(d.mime, 'image/png');
      expect(d.uploaded, DateTime.fromMillisecondsSinceEpoch(1000000 * 1000));
    });
  });

  group('BlobDescriptor.fromJson — mime fallback branches', () {
    test('defaults to application/octet-stream when `type` is omitted', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(type: null));
      expect(d.mime, 'application/octet-stream');
    });

    test('defaults to application/octet-stream when `type` is explicit null',
        () {
      final d = BlobDescriptor.fromJson(
        aBlobDescriptorJson(type: null, explicit: const {'type': null}),
      );
      expect(d.mime, 'application/octet-stream');
    });

    test('preserves an unusual but valid mime string', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(
        type: 'application/vnd.custom+json; charset=utf-8',
      ));
      expect(d.mime, 'application/vnd.custom+json; charset=utf-8');
    });

    // The mime field is a passthrough — no per-type parsing. Test a
    // representative sample of what the app actually uploads so a future
    // regression that starts munging content-types (e.g. stripping
    // parameters, normalizing to lowercase) trips immediately.
    for (final mime in const [
      // images
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'image/svg+xml',
      'image/heic',
      'image/tiff',
      // pdf
      'application/pdf',
      // office — legacy
      'application/msword', // .doc
      'application/vnd.ms-excel', // .xls
      'application/vnd.ms-powerpoint', // .ppt
      // office — OOXML
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
      'application/vnd.openxmlformats-officedocument.presentationml.presentation', // .pptx
      // open document
      'application/vnd.oasis.opendocument.text', // .odt
      'application/vnd.oasis.opendocument.spreadsheet', // .ods
      'application/vnd.oasis.opendocument.presentation', // .odp
      // video
      'video/mp4',
      'video/quicktime',
      'video/webm',
      // audio
      'audio/mpeg',
      'audio/ogg',
      'audio/wav',
      'audio/mp4',
      // text / data
      'text/plain',
      'text/markdown',
      'text/csv',
      'application/json',
      'application/xml',
      // archives
      'application/zip',
      'application/x-tar',
      'application/gzip',
      // generic
      'application/octet-stream',
    ]) {
      test('preserves `$mime` unchanged', () {
        final d = BlobDescriptor.fromJson(aBlobDescriptorJson(type: mime));
        expect(d.mime, mime);
      });
    }
  });

  group('BlobDescriptor.fromJson — `uploaded` branches', () {
    test('null when server omits the field', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson());
      expect(d.uploaded, isNull);
    });

    test('null when server sends an explicit null', () {
      final d = BlobDescriptor.fromJson(
        aBlobDescriptorJson(explicit: const {'uploaded': null}),
      );
      expect(d.uploaded, isNull);
    });

    test('null when server sends the wrong type (string, not num)', () {
      final d = BlobDescriptor.fromJson(
        aBlobDescriptorJson(explicit: const {'uploaded': '1000000'}),
      );
      expect(d.uploaded, isNull);
    });

    test('parses double-typed `uploaded` (num covers int and double)', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(uploaded: 1000000.0));
      expect(d.uploaded, DateTime.fromMillisecondsSinceEpoch(1000000 * 1000));
    });

    test('unix epoch 0 → 1970-01-01', () {
      final d = BlobDescriptor.fromJson(
        aBlobDescriptorJson(explicit: const {'uploaded': 0}),
      );
      expect(d.uploaded, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('BlobDescriptor.fromJson — size branches', () {
    test('zero-byte blob', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(size: 0));
      expect(d.size, 0);
    });

    test('accepts a double-typed size (some relays JSON-encode as double)',
        () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(size: 1024.0));
      expect(d.size, 1024);
    });

    test('large size within JS-safe integer range', () {
      const big = 9007199254740992; // 2^53
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(size: big));
      expect(d.size, big);
    });
  });

  group('BlobDescriptor.fromJson — url payload variants', () {
    test('preserves a very long URL unchanged', () {
      final url = 'https://cdn.example/${'a' * 500}.jpg';
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(url: url));
      expect(d.url, url);
    });

    test('preserves an IDN / unicode-bearing URL unchanged', () {
      // fromJson does no url parsing — unicode chars in the path must pass
      // through verbatim.
      const url = 'https://cdn.example/${Content.unicode}.jpg';
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(url: url));
      expect(d.url, url);
    });

    test('preserves an empty-string URL (contract does not sanitize)', () {
      final d = BlobDescriptor.fromJson(aBlobDescriptorJson(url: ''));
      expect(d.url, '');
    });
  });

  group('BlobDescriptor.fromJson — malformed / type-confused payloads', () {
    Map<String, dynamic> without(String key) {
      final m = aBlobDescriptorJson();
      m.remove(key);
      return m;
    }

    test('throws when required `url` is missing', () {
      expect(
        () => BlobDescriptor.fromJson(without('url')),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws when required `sha256` is missing', () {
      expect(
        () => BlobDescriptor.fromJson(without('sha256')),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws when required `size` is missing', () {
      expect(
        () => BlobDescriptor.fromJson(without('size')),
        // `(null as num).toInt()` → NoSuchMethodError, not TypeError, on VM.
        // `isA<Error>` covers both platforms.
        throwsA(isA<Error>()),
      );
    });

    test('throws when `url` is the wrong type (int, not String)', () {
      expect(
        () => BlobDescriptor.fromJson(
          aBlobDescriptorJson(explicit: const {'url': 123}),
        ),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws when `size` is the wrong type (String, not num)', () {
      expect(
        () => BlobDescriptor.fromJson(
          aBlobDescriptorJson(explicit: const {'size': '1'}),
        ),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws when `type` is the wrong type (int, not String)', () {
      expect(
        () => BlobDescriptor.fromJson(
          aBlobDescriptorJson(explicit: const {'type': 123}),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ── HTTP methods ────────────────────────────────────────────────────────

  BlossomClient clientFor(MockClient http) =>
      BlossomClient(httpClient: http);

  Map<String, dynamic> decodeAuth(String header) {
    expect(header, startsWith('Nostr '));
    final b64 = header.substring('Nostr '.length);
    final json = utf8.decode(base64.decode(b64));
    return jsonDecode(json) as Map<String, dynamic>;
  }

  group('head', () {
    test('returns true on 200', () async {
      final http = MockClient((req) async {
        expect(req.method, 'HEAD');
        expect(req.url.toString(), 'https://s/abc.jpg');
        return http_.Response('', 200);
      });
      expect(await clientFor(http).head('https://s', 'abc', ext: 'jpg'), isTrue);
    });

    test('returns false on 404', () async {
      final http = MockClient((_) async => http_.Response('', 404));
      expect(await clientFor(http).head('https://s', 'abc', ext: 'jpg'), isFalse);
    });

    test('omits .ext when ext is null', () async {
      String? seen;
      final http = MockClient((req) async {
        seen = req.url.toString();
        return http_.Response('', 200);
      });
      await clientFor(http).head('https://s', 'abc');
      expect(seen, 'https://s/abc');
    });
  });

  group('upload', () {
    http_.Response okDescriptor() => http_.Response(
          jsonEncode(aBlobDescriptorJson(
            url: 'https://s/abc.jpg',
            sha256: 'abc',
            size: 3,
            type: 'image/jpeg',
          )),
          200,
        );

    test('sends PUT /upload with signed Kind-24242 Authorization header',
        () async {
      Map<String, dynamic>? evt;
      http_.BaseRequest? seenReq;
      final http = MockClient((req) async {
        seenReq = req;
        evt = decodeAuth(req.headers['Authorization']!);
        return okDescriptor();
      });

      final res = await clientFor(http).upload(
        serverUrl: 'https://s',
        bytes: Uint8List.fromList([1, 2, 3]),
        mime: 'image/jpeg',
        sha256: 'abc',
        keys: testKeys,
      );

      expect(seenReq!.method, 'PUT');
      expect(seenReq!.url.toString(), 'https://s/upload');
      expect(seenReq!.headers['Content-Type'], 'image/jpeg');
      expect(seenReq!.headers['Content-Length'], '3');

      expect(evt!['kind'], 24242);
      expect(evt!['pubkey'] as String, matches(r'^[0-9a-f]{64}$'));
      expect(evt!['content'], 'Upload');
      final tags = (evt!['tags'] as List).cast<List>();
      expect(tags[0], ['t', 'upload']);
      expect(tags[1], ['x', 'abc']);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expSec = int.parse(tags[2][1] as String);
      expect(expSec - nowSec, inInclusiveRange(295, 310));

      expect(res.sha256, 'abc');
      expect(res.size, 3);
    });

    test('accepts 201 Created as success (BUD-02 allows both)', () async {
      final http = MockClient((_) async => http_.Response(
          jsonEncode(aBlobDescriptorJson()), 201));
      final res = await clientFor(http).upload(
        serverUrl: 'https://s',
        bytes: Uint8List(1),
        mime: 'image/jpeg',
        sha256: 'sha',
        keys: testKeys,
      );
      expect(res.sha256, 'sha');
    });

    test('413 → "file too large" reason (nginx pre-Blossom rejection)',
        () async {
      final http = MockClient((_) async =>
          http_.Response('<html>413</html>', 413));
      await expectLater(
        clientFor(http).upload(
          serverUrl: 'https://s',
          bytes: Uint8List(1),
          mime: 'image/jpeg',
          sha256: 'sha',
          keys: testKeys,
        ),
        throwsA(isA<BlossomException>()
            .having((e) => e.statusCode, 'code', 413)
            .having((e) => e.reason, 'reason', contains('too large'))),
      );
    });

    test('other error uses x-reason header when present', () async {
      final http = MockClient((_) async => http_.Response(
            'boom',
            500,
            headers: {'x-reason': 'server explosion'},
          ));
      await expectLater(
        clientFor(http).upload(
          serverUrl: 'https://s',
          bytes: Uint8List(1),
          mime: 'image/jpeg',
          sha256: 'sha',
          keys: testKeys,
        ),
        throwsA(isA<BlossomException>()
            .having((e) => e.reason, 'reason', 'server explosion')),
      );
    });

    test('other error falls back to body when x-reason is absent', () async {
      final http = MockClient((_) async =>
          http_.Response('raw body reason', 500));
      await expectLater(
        clientFor(http).upload(
          serverUrl: 'https://s',
          bytes: Uint8List(1),
          mime: 'image/jpeg',
          sha256: 'sha',
          keys: testKeys,
        ),
        throwsA(isA<BlossomException>()
            .having((e) => e.reason, 'reason', 'raw body reason')),
      );
    });
  });

  group('download / downloadFromUrl', () {
    test('download returns body bytes on 200', () async {
      final http = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.toString(), 'https://s/abc.jpg');
        return http_.Response.bytes([9, 9, 9], 200);
      });
      final b = await clientFor(http).download('https://s', 'abc', ext: 'jpg');
      expect(b, [9, 9, 9]);
    });

    test('download throws BlossomException on non-200', () async {
      final http = MockClient(
          (_) async => http_.Response('nope', 404, headers: {'x-reason': 'gone'}));
      await expectLater(
        clientFor(http).download('https://s', 'abc'),
        throwsA(isA<BlossomException>()
            .having((e) => e.statusCode, 'code', 404)
            .having((e) => e.reason, 'reason', 'gone')),
      );
    });

    test('downloadFromUrl coerces wss:// → https://', () async {
      String? seen;
      final http = MockClient((req) async {
        seen = req.url.toString();
        return http_.Response.bytes([1], 200);
      });
      await clientFor(http).downloadFromUrl('wss://cdn/abc.jpg');
      expect(seen, 'https://cdn/abc.jpg');
    });

    test('downloadFromUrl coerces ws:// → http://', () async {
      String? seen;
      final http = MockClient((req) async {
        seen = req.url.toString();
        return http_.Response.bytes([1], 200);
      });
      await clientFor(http).downloadFromUrl('ws://cdn/abc.jpg');
      expect(seen, 'http://cdn/abc.jpg');
    });

    test('downloadFromUrl leaves https:// untouched', () async {
      String? seen;
      final http = MockClient((req) async {
        seen = req.url.toString();
        return http_.Response.bytes([1], 200);
      });
      await clientFor(http).downloadFromUrl('https://cdn/abc.jpg');
      expect(seen, 'https://cdn/abc.jpg');
    });

    test('downloadFromUrl throws on non-200', () async {
      final http = MockClient((_) async => http_.Response('nope', 500));
      await expectLater(
        clientFor(http).downloadFromUrl('https://cdn/abc.jpg'),
        throwsA(isA<BlossomException>()),
      );
    });
  });

  group('list', () {
    test('sends GET /list/<pubkey> with signed Kind-24242 Authorization',
        () async {
      Map<String, dynamic>? evt;
      http_.BaseRequest? seenReq;
      final http = MockClient((req) async {
        seenReq = req;
        evt = decodeAuth(req.headers['Authorization']!);
        return http_.Response(jsonEncode([aBlobDescriptorJson()]), 200);
      });
      final res = await clientFor(http).list(
        serverUrl: 'https://s',
        pubkeyHex: 'PUB',
        keys: testKeys,
      );

      expect(seenReq!.method, 'GET');
      expect(seenReq!.url.toString(), 'https://s/list/PUB');
      expect(evt!['kind'], 24242);
      final tags = (evt!['tags'] as List).cast<List>();
      expect(tags[0], ['t', 'list']);
      expect(tags.any((t) => t[0] == 'x'), isFalse);
      expect(res, hasLength(1));
    });

    test('parses each descriptor via BlobDescriptor.fromJson', () async {
      final http = MockClient((_) async => http_.Response(
            jsonEncode([
              aBlobDescriptorJson(sha256: 'a', type: 'image/jpeg'),
              aBlobDescriptorJson(sha256: 'b', type: 'application/pdf'),
            ]),
            200,
          ));
      final res = await clientFor(http).list(
        serverUrl: 'https://s',
        pubkeyHex: 'p',
        keys: testKeys,
      );
      expect(res.map((d) => d.sha256).toList(), ['a', 'b']);
      expect(res.last.mime, 'application/pdf');
    });

    test('throws when body is not an array', () async {
      final http = MockClient(
          (_) async => http_.Response(jsonEncode({'oops': true}), 200));
      await expectLater(
        clientFor(http).list(
          serverUrl: 'https://s',
          pubkeyHex: 'p',
          keys: testKeys,
        ),
        throwsA(isA<BlossomException>()
            .having((e) => e.reason, 'reason', contains('array'))),
      );
    });

    test('throws on non-200', () async {
      final http = MockClient(
          (_) async => http_.Response('unauth', 401, headers: {'x-reason': 'auth'}));
      await expectLater(
        clientFor(http).list(
          serverUrl: 'https://s',
          pubkeyHex: 'p',
          keys: testKeys,
        ),
        throwsA(isA<BlossomException>()
            .having((e) => e.statusCode, 'code', 401)
            .having((e) => e.reason, 'reason', 'auth')),
      );
    });
  });

  group('deleteRemote', () {
    test('sends DELETE /<sha> with signed Kind-24242 Authorization',
        () async {
      Map<String, dynamic>? evt;
      http_.BaseRequest? seenReq;
      final http = MockClient((req) async {
        seenReq = req;
        evt = decodeAuth(req.headers['Authorization']!);
        return http_.Response('', 200);
      });
      await clientFor(http).deleteRemote(
        serverUrl: 'https://s',
        sha256: 'sha',
        keys: testKeys,
      );
      expect(seenReq!.method, 'DELETE');
      expect(seenReq!.url.toString(), 'https://s/sha');
      final tags = (evt!['tags'] as List).cast<List>();
      expect(tags[0], ['t', 'delete']);
      expect(tags[1], ['x', 'sha']);
    });

    test('accepts 204 No Content as success', () async {
      final http = MockClient((_) async => http_.Response('', 204));
      await clientFor(http).deleteRemote(
        serverUrl: 'https://s',
        sha256: 'sha',
        keys: testKeys,
      );
    });

    test('throws on other status', () async {
      final http = MockClient((_) async =>
          http_.Response('', 403, headers: {'x-reason': 'not owner'}));
      await expectLater(
        clientFor(http).deleteRemote(
          serverUrl: 'https://s',
          sha256: 'sha',
          keys: testKeys,
        ),
        throwsA(isA<BlossomException>()
            .having((e) => e.statusCode, 'code', 403)
            .having((e) => e.reason, 'reason', 'not owner')),
      );
    });
  });
}
