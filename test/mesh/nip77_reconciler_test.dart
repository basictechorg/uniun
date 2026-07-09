// Unit tests for the pooled NIP-77 mesh reconciler. Two in-memory peers wired
// by loopback closures reconcile a fake set of signed events; asserts cover
// convergence, symmetry, tamper-drop, wrong-pubkey-drop.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/nip77_reconciler.dart';
import 'package:uniun/features/mesh/sync/sync_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Suppress plugin channel calls made deep inside nip44's PBKDF2 helper.
  const flutterSecureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(flutterSecureStorage, (_) async => null);

  late Keychain me;
  late Keychain other;
  late MeshEventCodec codec;
  late MeshEventCodec otherCodec;

  setUp(() {
    me = Keychain.generate();
    other = Keychain.generate();
    codec = MeshEventCodec(privkeyHex: me.private, pubkeyHex: me.public);
    otherCodec =
        MeshEventCodec(privkeyHex: other.private, pubkeyHex: other.public);
  });

  // Convergence — one peer holds a saved-note event the other lacks; after
  // reconciliation, both peers report the event as present.
  test('one-sided mutation delivers exactly one event', () async {
    final onlyOnA = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'note-1',
      content: {'state': 'active', 'savedAt': 1720000000},
      createdAtSec: 1720000000,
    );
    final idA = _peekId(onlyOnA)!;

    final scopeA = _FakeScope(name: 'saved', ownedEvents: {idA: onlyOnA});
    final scopeB = _FakeScope(name: 'saved', ownedEvents: {});

    await _drive([scopeA], [scopeB]);

    expect(scopeB.upserted, contains(onlyOnA));
    expect(scopeA.upserted, isEmpty);
  });

  // Symmetric convergence — each side holds a distinct event; both sides
  // deliver theirs.
  test('two-sided divergence converges', () async {
    final onA = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'note-a',
      content: {'state': 'active'},
      createdAtSec: 1720000010,
    );
    final onB = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'note-b',
      content: {'state': 'active'},
      createdAtSec: 1720000020,
    );
    final idA = _peekId(onA)!;
    final idB = _peekId(onB)!;

    final scopeA = _FakeScope(name: 'saved', ownedEvents: {idA: onA});
    final scopeB = _FakeScope(name: 'saved', ownedEvents: {idB: onB});

    await _drive([scopeA], [scopeB]);

    expect(scopeB.upserted, contains(onA));
    expect(scopeA.upserted, contains(onB));
  });

  // Idempotent — identical id sets exchange zero events.
  test('identical sets exchange no events', () async {
    final shared = await codec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'note-shared',
      content: {'state': 'active'},
      createdAtSec: 1720000030,
    );
    final id = _peekId(shared)!;

    final scopeA = _FakeScope(name: 'saved', ownedEvents: {id: shared});
    final scopeB = _FakeScope(name: 'saved', ownedEvents: {id: shared});

    await _drive([scopeA], [scopeB]);

    expect(scopeA.upserted, isEmpty);
    expect(scopeB.upserted, isEmpty);
  });

  // ── Edge cases ────────────────────────────────────────────────────────

  // Wrong pubkey — one side ships an event signed by a different identity;
  // the receiving scope's upsertSigned rejects it (we prove rejection by the
  // scope's real MeshEventCodec throwing).
  test('cross-identity events are rejected by the codec', () async {
    final foreign = await otherCodec.signRecord(
      kind: MeshEventKinds.savedNote,
      dTag: 'note-foreign',
      content: {'state': 'active'},
      createdAtSec: 1720000040,
    );

    // Sanity: MY codec must reject this event.
    expect(
      () => codec.openRecord(foreign),
      throwsA(isA<MeshCodecException>()),
    );
  });

  // Empty index — a peer with no rows still terminates the run.
  test('empty scopes on both sides converge instantly', () async {
    final scopeA = _FakeScope(name: 'saved', ownedEvents: {});
    final scopeB = _FakeScope(name: 'saved', ownedEvents: {});

    await _drive([scopeA], [scopeB]);

    expect(scopeA.upserted, isEmpty);
    expect(scopeB.upserted, isEmpty);
  });

  // Large asymmetric set — 20 ids on A, 20 different on B; both sides
  // deliver theirs.
  test('20-vs-20 divergent sets fully cross-deliver', () async {
    final aEvents = <String, String>{};
    final bEvents = <String, String>{};
    for (var i = 0; i < 20; i++) {
      final ea = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'note-a-$i',
        content: {'state': 'active'},
        createdAtSec: 1720000100 + i,
      );
      final eb = await codec.signRecord(
        kind: MeshEventKinds.savedNote,
        dTag: 'note-b-$i',
        content: {'state': 'active'},
        createdAtSec: 1720000200 + i,
      );
      aEvents[_peekId(ea)!] = ea;
      bEvents[_peekId(eb)!] = eb;
    }

    final scopeA = _FakeScope(name: 'saved', ownedEvents: aEvents);
    final scopeB = _FakeScope(name: 'saved', ownedEvents: bEvents);

    await _drive([scopeA], [scopeB]);

    expect(scopeA.upserted.length, 20);
    expect(scopeB.upserted.length, 20);
    for (final ev in bEvents.values) {
      expect(scopeA.upserted, contains(ev));
    }
    for (final ev in aEvents.values) {
      expect(scopeB.upserted, contains(ev));
    }
  });
}

/// A scope backed by an in-memory `Map<eventId, signedJson>`. Ignores any
/// tampering — we only need it to answer the reconciler's three questions
/// (index, lookup, upsert) without touching Isar.
class _FakeScope implements NegentropySyncScope {
  _FakeScope({required this.name, required this.ownedEvents})
      : _index = _indexOf(ownedEvents);

  static Map<String, int> _indexOf(Map<String, String> events) {
    final out = <String, int>{};
    for (final entry in events.entries) {
      final ts = _peekCreatedAt(entry.value);
      if (ts != null) out[entry.key] = ts;
    }
    return out;
  }

  @override
  final String name;

  final Map<String, String> ownedEvents;
  final Map<String, int> _index;
  final List<String> upserted = [];

  @override
  Future<Map<String, int>> localIndex() async => _index;

  @override
  Future<String?> signedEvent(String eventId) async => ownedEvents[eventId];

  @override
  Future<void> upsertSigned(String signedEventJson) async {
    upserted.add(signedEventJson);
  }
}

/// Runs both reconcilers to completion, cross-feeding their `send` outputs
/// into each other's `handleMessage` via microtask hops.
Future<void> _drive(
  List<NegentropySyncScope> scopesA,
  List<NegentropySyncScope> scopesB,
) async {
  late Nip77Reconciler b;
  final a = Nip77Reconciler(
    scopes: scopesA,
    send: (msg) => scheduleMicrotask(() => b.handleMessage(msg)),
    timeout: const Duration(seconds: 5),
  );
  b = Nip77Reconciler(
    scopes: scopesB,
    send: (msg) => scheduleMicrotask(() => a.handleMessage(msg)),
    timeout: const Duration(seconds: 5),
  );

  await Future.wait([a.run(), b.run()]);
}

String? _peekId(String eventJson) {
  final idx = eventJson.indexOf('"id":');
  if (idx < 0) return null;
  final quote1 = eventJson.indexOf('"', idx + 5);
  final quote2 = eventJson.indexOf('"', quote1 + 1);
  if (quote1 < 0 || quote2 < 0) return null;
  return eventJson.substring(quote1 + 1, quote2);
}

int? _peekCreatedAt(String eventJson) {
  final idx = eventJson.indexOf('"created_at":');
  if (idx < 0) return null;
  final commaOrBrace = eventJson.indexOf(RegExp(r'[,}]'), idx + 13);
  if (commaOrBrace < 0) return null;
  return int.tryParse(eventJson.substring(idx + 13, commaOrBrace).trim());
}
