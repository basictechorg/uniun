import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/qr/uniun_qr_payload.dart';

void main() {
  group('encode', () {
    test('user payload omits relays + name when absent', () {
      const p = UniunQrPayload(kind: UniunQrKind.user, id: 'npub1abc');
      final j = jsonDecode(p.encode()) as Map<String, dynamic>;
      expect(j, {'kind': 'user', 'id': 'npub1abc'});
    });

    test('public group encodes "public" + relays', () {
      const p = UniunQrPayload(
        kind: UniunQrKind.publicGroup,
        id: 'hex1',
        name: 'Devs',
        relays: ['wss://r1', 'wss://r2'],
      );
      final j = jsonDecode(p.encode()) as Map<String, dynamic>;
      expect(j['kind'], 'public');
      expect(j['id'], 'hex1');
      expect(j['name'], 'Devs');
      expect(j['relays'], ['wss://r1', 'wss://r2']);
    });

    test('private group encodes "private"', () {
      const p = UniunQrPayload(kind: UniunQrKind.privateGroup, id: 'g1');
      final j = jsonDecode(p.encode()) as Map<String, dynamic>;
      expect(j['kind'], 'private');
    });

    test('null name is dropped from the JSON', () {
      const p = UniunQrPayload(kind: UniunQrKind.user, id: 'x');
      expect(p.encode().contains('name'), isFalse);
    });

    test('empty relays list is dropped from the JSON', () {
      const p = UniunQrPayload(kind: UniunQrKind.publicGroup, id: 'x');
      expect(p.encode().contains('relays'), isFalse);
    });
  });

  group('decode — bare npub forms', () {
    test('bare `npub1…` becomes user kind', () {
      final p = UniunQrPayload.decode('npub1xyz');
      expect(p.kind, UniunQrKind.user);
      expect(p.id, 'npub1xyz');
    });

    test('`nostr:npub1…` strips the URI prefix', () {
      final p = UniunQrPayload.decode('nostr:npub1abcd');
      expect(p.kind, UniunQrKind.user);
      expect(p.id, 'npub1abcd');
    });

    test('whitespace around bare npub is trimmed', () {
      final p = UniunQrPayload.decode('   npub1zzz  ');
      expect(p.id, 'npub1zzz');
    });
  });

  group('decode — QR-login URI', () {
    test('uniun://qr-login?s=<id> becomes loginSession', () {
      final p =
          UniunQrPayload.decode('uniun://qr-login?s=abc123session');
      expect(p.kind, UniunQrKind.loginSession);
      expect(p.id, 'abc123session');
    });

    test('is case-insensitive on the scheme', () {
      final p =
          UniunQrPayload.decode('UNIUN://QR-login?s=abc123session');
      expect(p.kind, UniunQrKind.loginSession);
    });

    test('whitespace around the URI is trimmed', () {
      final p =
          UniunQrPayload.decode('  uniun://qr-login?s=sess1  ');
      expect(p.id, 'sess1');
    });

    test('missing `s` query param throws', () {
      expect(() => UniunQrPayload.decode('uniun://qr-login'),
          throwsA(isA<FormatException>()));
    });

    test('empty `s` query param throws', () {
      expect(() => UniunQrPayload.decode('uniun://qr-login?s='),
          throwsA(isA<FormatException>()));
    });

    test('round-trips through JSON kind "login"', () {
      const original =
          UniunQrPayload(kind: UniunQrKind.loginSession, id: 'sess-x');
      final round = UniunQrPayload.decode(original.encode());
      expect(round.kind, UniunQrKind.loginSession);
      expect(round.id, 'sess-x');
    });
  });

  group('decode — JSON object', () {
    test('round-trips a publicGroup', () {
      const original = UniunQrPayload(
        kind: UniunQrKind.publicGroup,
        id: 'cid',
        name: 'name',
        relays: ['wss://a'],
      );
      final round = UniunQrPayload.decode(original.encode());
      expect(round.kind, UniunQrKind.publicGroup);
      expect(round.id, 'cid');
      expect(round.name, 'name');
      expect(round.relays, ['wss://a']);
    });

    test('round-trips a user with explicit JSON', () {
      const original = UniunQrPayload(kind: UniunQrKind.user, id: 'npub1u');
      final round = UniunQrPayload.decode(original.encode());
      expect(round.kind, UniunQrKind.user);
      expect(round.id, 'npub1u');
    });

    test('round-trips a privateGroup', () {
      const original = UniunQrPayload(kind: UniunQrKind.privateGroup, id: 'g');
      final round = UniunQrPayload.decode(original.encode());
      expect(round.kind, UniunQrKind.privateGroup);
    });

    test('trims id whitespace', () {
      final p = UniunQrPayload.decode('{"kind":"user","id":"  abc  "}');
      expect(p.id, 'abc');
    });

    test('trims name whitespace', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","name":" Devs "}');
      expect(p.name, 'Devs');
    });

    test('relays dedupes + drops empty entries', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","relays":["wss://r","wss://r","","   "]}');
      expect(p.relays, ['wss://r']);
    });

    test('relays accepts any List, stringifies entries', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","relays":[1, 2, "wss://r"]}');
      expect(p.relays.toSet(), {'1', '2', 'wss://r'});
    });

    test('non-list relays becomes empty', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","relays":"wss://r"}');
      expect(p.relays, isEmpty);
    });
  });

  group('decode — error paths', () {
    test('empty input throws', () {
      expect(() => UniunQrPayload.decode(''),
          throwsA(isA<FormatException>()));
    });

    test('whitespace-only input throws', () {
      expect(() => UniunQrPayload.decode('   \n\t  '),
          throwsA(isA<FormatException>()));
    });

    test('non-JSON garbage throws', () {
      expect(() => UniunQrPayload.decode('not json at all'),
          throwsA(isA<FormatException>()));
    });

    test('JSON array (not object) throws', () {
      expect(() => UniunQrPayload.decode('[1,2,3]'),
          throwsA(isA<FormatException>()));
    });

    test('unknown kind throws', () {
      expect(() => UniunQrPayload.decode('{"kind":"alien","id":"x"}'),
          throwsA(isA<FormatException>()));
    });

    test('missing id throws', () {
      expect(() => UniunQrPayload.decode('{"kind":"user"}'),
          throwsA(isA<FormatException>()));
    });

    test('empty id throws', () {
      expect(() => UniunQrPayload.decode('{"kind":"user","id":""}'),
          throwsA(isA<FormatException>()));
    });

    test('whitespace-only id throws', () {
      expect(() => UniunQrPayload.decode('{"kind":"user","id":"   "}'),
          throwsA(isA<FormatException>()));
    });

    test('missing kind throws', () {
      expect(() => UniunQrPayload.decode('{"id":"x"}'),
          throwsA(isA<FormatException>()));
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('malformed JSON', () {
    test('half-open object throws', () {
      expect(() => UniunQrPayload.decode('{"kind":"user","id":"a"'),
          throwsA(isA<FormatException>()));
    });

    test('numeric top-level throws', () {
      expect(() => UniunQrPayload.decode('42'),
          throwsA(isA<FormatException>()));
    });

    test('JSON null top-level throws', () {
      expect(() => UniunQrPayload.decode('null'),
          throwsA(isA<FormatException>()));
    });

    test('JSON true throws', () {
      expect(() => UniunQrPayload.decode('true'),
          throwsA(isA<FormatException>()));
    });

    test('string top-level throws', () {
      expect(() => UniunQrPayload.decode('"just a string"'),
          throwsA(isA<FormatException>()));
    });

    test('unknown top-level keys are ignored', () {
      final p = UniunQrPayload.decode(
          '{"kind":"user","id":"x","extra":{"a":1},"v":2}');
      expect(p.kind, UniunQrKind.user);
      expect(p.id, 'x');
    });
  });

  group('field type confusion', () {
    test('numeric id throws (current behaviour: `as String?` rejects int)', () {
      expect(() => UniunQrPayload.decode('{"kind":"user","id":42}'),
          throwsA(isA<Object>()));
    });

    test('numeric name throws (same path)', () {
      expect(
          () => UniunQrPayload.decode('{"kind":"public","id":"g","name":99}'),
          throwsA(isA<Object>()));
    });

    test('object kind throws', () {
      expect(() => UniunQrPayload.decode('{"kind":{},"id":"x"}'),
          throwsA(isA<FormatException>()));
    });
  });

  group('unicode payloads', () {
    test('emoji name survives round-trip', () {
      const p = UniunQrPayload(
        kind: UniunQrKind.publicGroup,
        id: 'g',
        name: '🐉 Dragons',
      );
      expect(UniunQrPayload.decode(p.encode()).name, '🐉 Dragons');
    });

    test('RTL name survives round-trip', () {
      const p = UniunQrPayload(
        kind: UniunQrKind.publicGroup,
        id: 'g',
        name: 'مرحبا',
      );
      expect(UniunQrPayload.decode(p.encode()).name, 'مرحبا');
    });
  });

  group('bare npub edges', () {
    test('npub with trailing tab is trimmed', () {
      final p = UniunQrPayload.decode('npub1abc\t');
      expect(p.kind, UniunQrKind.user);
    });

    test('`npub` without `1` is NOT a user payload (falls to JSON)', () {
      expect(() => UniunQrPayload.decode('npubABCD'),
          throwsA(isA<FormatException>()));
    });

    test('`nostr:` prefix without npub falls to JSON parse', () {
      expect(() => UniunQrPayload.decode('nostr:other-thing'),
          throwsA(isA<FormatException>()));
    });
  });

  group('relays at scale', () {
    test('100 relays (50 duplicated) dedupes to 50', () {
      final relays = [
        for (var i = 0; i < 50; i++) ...['wss://r$i', 'wss://r$i']
      ];
      final p = UniunQrPayload.decode(jsonEncode({
        'kind': 'public',
        'id': 'g',
        'relays': relays,
      }));
      expect(p.relays.length, 50);
    });

    test('null entries stringify to "null" (current behaviour)', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","relays":[null,"wss://r"]}');
      expect(p.relays, containsAll(['null', 'wss://r']));
    });

    test('whitespace-padded entries are trimmed before dedup', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","relays":["wss://r","  wss://r ","wss://r"]}');
      expect(p.relays, ['wss://r']);
    });

    test('only-whitespace entries are dropped', () {
      final p = UniunQrPayload.decode(
          '{"kind":"public","id":"g","relays":["   ","\\t","wss://r"]}');
      expect(p.relays, ['wss://r']);
    });
  });

  group('encode invariants', () {
    test('no `name` key when name is null', () {
      const p = UniunQrPayload(kind: UniunQrKind.user, id: 'x');
      expect(p.encode().contains('"name"'), isFalse);
    });

    test('no `relays` key when relays is empty', () {
      const p = UniunQrPayload(kind: UniunQrKind.publicGroup, id: 'g');
      expect(p.encode().contains('"relays"'), isFalse);
    });

    test('double round-trip preserves all fields', () {
      const original = UniunQrPayload(
        kind: UniunQrKind.publicGroup,
        id: 'cid',
        name: 'name',
        relays: ['wss://a', 'wss://b'],
      );
      final once = UniunQrPayload.decode(original.encode());
      final twice = UniunQrPayload.decode(once.encode());
      expect(twice.kind, original.kind);
      expect(twice.id, original.id);
      expect(twice.name, original.name);
      expect(twice.relays.toSet(), original.relays.toSet());
    });
  });
}
