import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';

import '../link/mesh_peer.dart';
import '../payload/payload_envelope.dart';
import '../router/mesh_router.dart';
import '../security/same_identity_cipher.dart';
import '../surrounding/broadcast_set_builder.dart';
import '../surrounding/surrounding_exchange.dart';
import '../surrounding/surrounding_inbound.dart';
import '../sync/mesh_event_codec.dart';
import '../sync/negentropy_sync_scopes.dart';
import '../sync/nip77_reconciler.dart';

/// Owns the per-peer sessions started after a successful identity handshake. Split
/// out of [MeshEngineHost] (which owns transports, discovery, the negotiator, and
/// lifecycle) so the host stays a thin coordinator and this logic is testable in
/// isolation.
///
///   * **same-identity** peer → a kept [Nip77Reconciler] (AEAD-sealed by [_cipher];
///     a local change re-runs a round via `run()` on the same session).
///   * **stranger / mesh** peer → a kept [SurroundingExchange] (delta broadcast) whose
///     inbound events flow through the shared [MeshRouter] (verify → store → relay).
///
/// Both maps are keyed by peer pubkey; a kept session lets a local content change
/// re-broadcast just the delta / re-run a round instead of rebuilding.
class MeshPeerSessions {
  MeshPeerSessions({
    required Isar isar,
    required String pubkeyHex,
    required String privkeyHex,
    required NoteRelationRepositoryImpl relations,
    required SameIdentityCipher? cipher,
    required MeshRouter router,
  })  : _isar = isar,
        _pubkeyHex = pubkeyHex,
        _privkeyHex = privkeyHex,
        _relations = relations,
        _cipher = cipher,
        _router = router;

  final Isar _isar;
  final String _pubkeyHex;
  final String _privkeyHex;
  final NoteRelationRepositoryImpl _relations;
  final SameIdentityCipher? _cipher;
  final MeshRouter _router;

  final Map<String, SurroundingExchange> _surrounding = {};
  final Map<String, Nip77Reconciler> _reconcilers = {};

  /// Start (or restart, on a link upgrade) the session for a freshly-proven peer.
  void onPeerAdded(MeshPeer peer) {
    switch (peer.mode) {
      case PeerMode.sameIdentity:
        _startSameIdentitySync(peer);
      case PeerMode.stranger:
      case PeerMode.mesh:
        _startSurroundingExchange(peer);
    }
  }

  /// Tear down a dropped peer's session.
  void onPeerRemoved(String pubkey) {
    _surrounding.remove(pubkey);
    _reconcilers.remove(pubkey);
  }

  /// Re-reconcile / re-broadcast to every connected peer (the host calls this,
  /// debounced, on a local content change). Idempotent.
  void resyncAll(Iterable<MeshPeer> peers) {
    for (final peer in peers) {
      switch (peer.mode) {
        case PeerMode.sameIdentity:
          final reconciler = _reconcilers[peer.pubkey];
          if (reconciler != null) {
            unawaited(reconciler.run().catchError(
                  (Object e) => debugPrint(
                      'MESH/NIP77: resync error with ${peer.pubkey.substring(0, 8)}…: $e'),
                ));
          } else {
            _startSameIdentitySync(peer);
          }
        case PeerMode.stranger:
        case PeerMode.mesh:
          final exchange = _surrounding[peer.pubkey];
          if (exchange != null) {
            unawaited(exchange.broadcast());
          } else {
            _startSurroundingExchange(peer);
          }
      }
    }
  }

  /// Exchanges public broadcast notes with a nearby stranger (the Surrounding feed):
  /// pushes our own + saved notes (outbound), and routes theirs through the multi-hop
  /// [MeshRouter] (verify → store → relay to other peers).
  void _startSurroundingExchange(MeshPeer peer) {
    final exchange = SurroundingExchange(
      send: peer.activeSession.send,
      broadcastSet: BroadcastSetBuilder(_isar, _pubkeyHex, _privkeyHex),
    );
    _surrounding[peer.pubkey] = exchange; // fresh session → fresh dedup state
    // Per-link ingestor (carries its own rate limit); the shared router dedupes +
    // relays across all peers.
    final inbound = SurroundingInbound(_isar, _pubkeyHex);
    peer.activeSession.onAppMessage((msg) {
      if (msg is EventMessage) {
        unawaited(_router.onEvent(peer.pubkey, inbound.ingest, msg));
      }
    });
    unawaited(exchange.broadcast().catchError(
          (Object e) => debugPrint('MESH: surrounding exchange error: $e'),
        ));
  }

  /// Reconciles all content scopes with a proven same-identity peer over its link.
  ///
  /// The channel is AEAD-encrypted ([_cipher]): the reconciler's negentropy
  /// frames — which carry decrypted DM/profile rows and self-encrypted mesh
  /// events — are sealed before send and opened on receipt, so they're never
  /// cleartext on the wire. Both devices derive the same key from the shared
  /// nsec, so the seal/open are symmetric. The reconciler is kept so a local
  /// change can re-run a round (`run()`) on the same session rather than rebuild it.
  void _startSameIdentitySync(MeshPeer peer) {
    // Drop any reconciler bound to a now-stale session (reconnect / link upgrade).
    _reconcilers.remove(peer.pubkey);
    final cipher = _cipher;
    final session = peer.activeSession;

    void send(MeshMessage m) {
      if (cipher == null) {
        session.send(m);
      } else {
        unawaited(cipher
            .seal(m.encode())
            .then((sealed) => session.send(EncryptedMessage(sealed))));
      }
    }

    final codec = MeshEventCodec(
      privkeyHex: _privkeyHex,
      pubkeyHex: _pubkeyHex,
    );
    final reconciler = Nip77Reconciler(
      scopes: buildNegentropySyncScopes(
        isar: _isar,
        codec: codec,
        relations: _relations,
        activePubkeyHex: _pubkeyHex,
      ),
      send: send,
    );
    _reconcilers[peer.pubkey] = reconciler;

    session.onAppMessage((m) {
      if (cipher == null) {
        reconciler.handleMessage(m);
      } else if (m is EncryptedMessage) {
        unawaited(cipher.open(m.payload).then((inner) {
          if (inner == null) return; // auth failure — drop
          final decoded = MeshMessage.decode(inner);
          if (decoded != null) reconciler.handleMessage(decoded);
        }));
      }
    });
    unawaited(reconciler.run().catchError(
          (Object e) => debugPrint(
              'MESH/NIP77: sync error with ${peer.pubkey.substring(0, 8)}…: $e'),
        ));
  }

  /// Drops all sessions (called on engine teardown).
  void dispose() {
    _reconcilers.clear();
    _surrounding.clear();
  }
}
