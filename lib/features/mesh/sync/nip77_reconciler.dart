import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nip77/nip77.dart' show Negentropy, NegentropyRecord;

import '../mesh_constants.dart';
import '../payload/payload_envelope.dart';
import 'mesh_event_codec.dart';
import 'sync_scope.dart';

/// Pooled negentropy-based mesh reconciler that replaces the bespoke
/// HAVE/NEED/ROWS diff engine (`TrustedSyncEngine`) with a single symmetric
/// NIP-77 round across **all** signed mesh-owned events (kinds 30500–30520 —
/// see [MeshEventKinds]).
///
/// # Why one pool
///
/// Event ids are globally unique (Schnorr-signed 32-byte digests). We don't
/// need a per-scope reconciliation session — instead we build one
/// `Map<eventId, createdAt>` union across every scope's
/// [NegentropySyncScope.localIndex],
/// hand it to a single [Negentropy] instance, and dispatch received events
/// back to the owning scope by asking each scope whether its
/// [NegentropySyncScope.signedEvent] recognises the id. This is what the plan §2a
/// prescribes: "pooled negentropy across all 3050x kinds".
///
/// # Symmetric bilateral run
///
/// The `nip77` package's [Negentropy] is a client-side implementation designed
/// to talk to a relay. Its `initiate()` emits fingerprint-mode ranges and its
/// `reconcile(peerBytes)` processes fingerprint/idList/skip responses — both
/// framings are symmetric enough to drive between two clients that each call
/// `initiate()` and cross-feed each other's bytes. Each side ends up with a
/// [ReconciliationResult.haveIds] (ids it holds that the peer lacks) and
/// [ReconciliationResult.needIds] (ids the peer holds that it lacks); both
/// sides then push their haves + request their needs.
///
/// # Wire framing
///
/// All frames are [SyncNip77Message]s wrapping the pooled negentropy dialect:
///
///   proto(bytes)  — negentropy protocol frame (initiator's tree or a
///                   responder's next round).
///   need(ids)     — "please send me these event JSONs".
///   events(json…) — signed Nostr event JSONs (one per requested id).
///   done          — reconciliation complete on my side.
///
/// The outer `MeshMessage` envelope is itself sealed by [`SameIdentityCipher`]
/// at the transport layer; this reconciler only cares about the parsed frames.
///
/// # Same-pubkey trust gate
///
/// Every received `events(...)` payload is passed straight to
/// [NegentropySyncScope.upsertSigned], which internally verifies via [MeshEventCodec]:
///   - re-serialize check → id equals `sha256(canonical)`.
///   - Schnorr signature valid.
///   - `event.pubkey == myPub` (rejects cross-identity injections).
///   - NIP-44 self-encrypted content decrypts.
/// Any failure is silently dropped (log + move on).
class Nip77Reconciler {
  Nip77Reconciler({
    required List<NegentropySyncScope> scopes,
    required void Function(MeshMessage) send,
    Duration timeout = kTrustedSyncTimeout,
  })  : _scopes = List.unmodifiable(scopes),
        _send = send,
        _timeout = timeout;

  final List<NegentropySyncScope> _scopes;
  final void Function(MeshMessage) _send;
  final Duration _timeout;

  Negentropy? _neg;
  Completer<void>? _done;
  bool _running = false;
  bool _localDone = false;
  bool _peerDone = false;
  final Set<String> _pendingNeed = {};
  // Frames received before `run()` finishes building `_neg` — most commonly the
  // peer's initial `proto` racing our own `_buildRecords()` await. We drain
  // these once the negentropy state is ready. Without this, whichever side
  // finishes `_buildRecords` first wins; the slower peer silently drops the
  // opening frame and reconciliation hangs.
  final List<SyncNip77Message> _prerunBuffer = [];

  /// Feed decoded `MeshMessage`s here. Non-nsync frames are ignored so this can
  /// share the same session channel as the legacy `SyncMessage` / `EventMessage`
  /// traffic.
  void handleMessage(MeshMessage msg) {
    if (msg is! SyncNip77Message) return;
    if (_neg == null) {
      _prerunBuffer.add(msg);
      return;
    }
    unawaited(_handle(msg).catchError(
      (Object e, StackTrace st) =>
          debugPrint('MESH/NIP77: handle error ($msg): $e\n$st'),
    ));
  }

  /// Starts (or restarts) reconciliation. Resolves when both sides have
  /// signalled `done` OR the timeout elapses.
  Future<void> run() async {
    if (_running) return _done!.future;
    _running = true;
    _localDone = false;
    _peerDone = false;
    _pendingNeed.clear();
    _done = Completer<void>();

    try {
      final records = await _buildRecords();
      _neg = Negentropy(records: records);
      final initial = _neg!.initiate();
      _send(SyncNip77Message(op: SyncNip77Op.proto, bytes: initial));

      // Drain any frames that arrived while we were awaiting Isar.
      if (_prerunBuffer.isNotEmpty) {
        final drained = List<SyncNip77Message>.of(_prerunBuffer);
        _prerunBuffer.clear();
        for (final m in drained) {
          unawaited(_handle(m).catchError(
            (Object e, StackTrace st) =>
                debugPrint('MESH/NIP77: drain error ($m): $e\n$st'),
          ));
        }
      }

      await _done!.future.timeout(
        _timeout,
        onTimeout: () {
          debugPrint('MESH/NIP77: reconciliation timed out after $_timeout');
          _finish();
        },
      );
    } finally {
      _running = false;
      _neg = null;
      _prerunBuffer.clear();
    }
  }

  Future<List<NegentropyRecord>> _buildRecords() async {
    final pooled = <String, int>{};
    for (final scope in _scopes) {
      final index = await scope.localIndex();
      pooled.addAll(index);
    }
    final records = <NegentropyRecord>[];
    for (final entry in pooled.entries) {
      if (entry.key.length != 64) continue;
      try {
        records.add(NegentropyRecord.fromHex(entry.value, entry.key));
      } catch (_) {
        // Skip malformed ids; the local table shouldn't hold non-hex event ids.
      }
    }
    return records;
  }

  Future<void> _handle(SyncNip77Message msg) async {
    switch (msg.op) {
      case SyncNip77Op.proto:
        await _handleProto(msg.bytes);
      case SyncNip77Op.need:
        await _handleNeed(msg.ids);
      case SyncNip77Op.events:
        await _handleEvents(msg.events);
      case SyncNip77Op.done:
        _peerDone = true;
        if (_localDone) _finish();
    }
  }

  Future<void> _handleProto(Uint8List? bytes) async {
    final neg = _neg;
    if (neg == null || bytes == null) return;

    Uint8List? next;
    try {
      next = neg.reconcile(bytes);
    } catch (e) {
      debugPrint('MESH/NIP77: reconcile threw: $e');
      _finish();
      return;
    }

    if (next != null) {
      _send(SyncNip77Message(op: SyncNip77Op.proto, bytes: next));
      return;
    }

    // Reconciliation converged on this side. Extract the diff.
    //
    // We only REQUEST via `need` — we deliberately do NOT ship `haveIds`
    // proactively even though negentropy tells us the peer lacks them. The
    // peer runs the same reconciliation symmetrically, so it will emit its
    // own `need` for those ids and we answer via [_handleNeed]. Skipping
    // the proactive send avoids duplicate deliveries (each event lands
    // exactly once per pair).
    final result = neg.getResult();
    final needIds = result?.needIds ?? const <String>[];

    if (needIds.isNotEmpty) {
      _pendingNeed.addAll(needIds);
      _send(SyncNip77Message(op: SyncNip77Op.need, ids: needIds));
    }

    _markLocalDoneIfIdle();
  }

  Future<void> _handleNeed(List<String> ids) async {
    if (ids.isEmpty) return;
    final payload = await _lookupEvents(ids);
    if (payload.isEmpty) return;
    _send(SyncNip77Message(op: SyncNip77Op.events, events: payload));
  }

  Future<void> _handleEvents(List<String> events) async {
    for (final json in events) {
      _pendingNeed.remove(_peekEventId(json));
      // Route to every scope; each verifies + drops if not its kind.
      for (final scope in _scopes) {
        try {
          await scope.upsertSigned(json);
        } catch (e) {
          debugPrint('MESH/NIP77: scope ${scope.name} upsertSigned: $e');
        }
      }
    }
    _markLocalDoneIfIdle();
  }

  Future<List<String>> _lookupEvents(List<String> ids) async {
    final out = <String>[];
    for (final id in ids) {
      for (final scope in _scopes) {
        final json = await scope.signedEvent(id);
        if (json != null) {
          out.add(json);
          break;
        }
      }
    }
    return out;
  }

  void _markLocalDoneIfIdle() {
    if (_localDone) return;
    if (_pendingNeed.isNotEmpty) return;
    _localDone = true;
    _send(const SyncNip77Message(op: SyncNip77Op.done));
    if (_peerDone) _finish();
  }

  void _finish() {
    if (_done != null && !_done!.isCompleted) _done!.complete();
  }

  /// Best-effort id extraction from a signed event JSON string. Used only to
  /// clear pending-need tracking; verification lives in [MeshEventCodec].
  String? _peekEventId(String eventJson) {
    // The event JSON always has `"id":"<64hex>"` near the top level. A
    // regex peek avoids a full jsonDecode for every incoming event — the
    // scope's upsertSigned does the real decode+verify.
    final idx = eventJson.indexOf('"id":');
    if (idx < 0) return null;
    final quote1 = eventJson.indexOf('"', idx + 5);
    if (quote1 < 0) return null;
    final quote2 = eventJson.indexOf('"', quote1 + 1);
    if (quote2 < 0 || quote2 - quote1 != 65) return null;
    return eventJson.substring(quote1 + 1, quote2);
  }
}
