import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/mesh/mesh_peer_state_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/saved_note_model.dart';
import 'package:uniun/data/repositories/note_relation_repository_impl.dart';

import '../handshake/nostr_mesh_signer.dart';
import '../link/mesh_link.dart';
import '../link/mesh_peer.dart';
import '../mesh_constants.dart';
import '../negotiator/mesh_peer_manager.dart';
import '../router/mesh_router.dart';
import '../security/same_identity_cipher.dart';
import '../surrounding/surrounding_cleanup.dart';
import '../transport/ble/ble_connector.dart';
import '../transport/lan/lan_connector.dart';
import '../transport/lan/lan_discovery.dart';
import '../transport/mesh_transport.dart';
import 'mesh_peer_sessions.dart';

/// The whole mesh engine: it owns mDNS discovery + dialing, the LAN/BLE transports,
/// the peer negotiator, and the sync/surrounding sessions. Everything above
/// [MeshLink] is transport-agnostic — every connected link flows through
/// `manager.onLinkConnected`.
///
/// It runs in one of two hosts (this class is identical in both; only `start`/`stop`
/// plumbing and [ownsIsar] differ):
///   * **Android** — inside a headless `FlutterEngine` hosted by the foreground
///     service (so the mesh survives backgrounding). It opens its own Isar
///     ([ownsIsar] = true) and native invokes `shutdown` over [_engineChannel].
///   * **iOS / macOS** — inline on the app's main isolate (foreground-only; no
///     second engine needed). It shares the app's Isar ([ownsIsar] = false, so
///     teardown never closes it) and `MeshService` calls [shutdown] directly.
///
/// The only cross-engine state is the [MeshPeerStateModel] peer-count mirror the UI
/// watches (relevant to the Android host; on Apple it's the same isolate).
class MeshEngineHost {
  MeshEngineHost(
    this._isar, {
    required String pubkeyHex,
    required String privkeyHex,
    this.ownsIsar = true,
  })  : _pubkeyHex = pubkeyHex,
        _privkeyHex = privkeyHex,
        _relations = NoteRelationRepositoryImpl(isar: _isar);

  final Isar _isar;
  // True when this host opened its own Isar (the Android headless engine); false
  // when it runs inline on the main isolate (iOS/macOS) sharing the app's Isar —
  // which it must NOT close.
  final bool ownsIsar;
  final String _pubkeyHex;
  final String _privkeyHex;
  final NoteRelationRepositoryImpl _relations;

  /// Native → engine control surface. Native invokes `shutdown` here for a graceful
  /// teardown right before it destroys the engine.
  static const MethodChannel _engineChannel =
      MethodChannel('in.uniun.app/mesh_engine');

  final LanConnector _connector = LanConnector();
  final BleConnector _bleConnector = BleConnector();
  // Every transport is wired into the negotiator identically; adding one (e.g.
  // Multipeer) is a single list entry. LAN keeps a typed ref for its port + dial.
  late final List<MeshTransport> _transports = [_connector, _bleConnector];
  final List<StreamSubscription<MeshLink>> _transportLinksSubs = [];
  LanDiscovery? _discovery;
  StreamSubscription<LanPeerEndpoint>? _discoverySub;
  // This engine's per-launch mDNS instance name — a random token, never the pubkey.
  String? _instanceName;
  // Peer instance-names we've already dialed — mDNS re-emits the same resolution
  // repeatedly, so dedupe (mirrors the old per-launch "dial once" set).
  final Set<String> _dialedPeers = {};

  // Network-change reactivity. A Wi-Fi switch leaves bonsoir's discovery sockets
  // bound to the now-dead interface, so mDNS silently stops advertising/resolving
  // and the LAN sync needs an app restart to recover. We watch connectivity and,
  // when the device's IPv4 set ACTUALLY changes (not just a connectivity-type
  // event), rebind the whole LAN layer in place — no app restart. BLE is untouched.
  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _lanRestartDebounce;
  Set<String> _lanAddrs = {};
  bool _lanRestarting = false;

  MeshPeerManager? _manager;
  // Per-peer sync / surrounding sessions — built in [start] once the cipher + router
  // exist; owns the kept Nip77Reconciler / SurroundingExchange per peer.
  MeshPeerSessions? _sessions;
  StreamSubscription<MeshPeerEvent>? _peerEventsSub;
  final List<StreamSubscription<void>> _changeWatchers = [];
  Timer? _surroundingCleanupTimer;
  Timer? _resyncDebounce;
  bool _shuttingDown = false;

  Future<void> start() async {
    _engineChannel.setMethodCallHandler(_onNativeCall);

    final signer = NostrMeshSigner(
      pubkeyHex: _pubkeyHex,
      privkeyHex: _privkeyHex,
    );
    final manager = MeshPeerManager(signer: signer);
    _manager = manager;
    // Multi-hop gossip relay (one shared seen-set) + same-identity channel cipher
    // (derived once from the shared nsec); both feed the per-peer sessions.
    final router = MeshRouter(peers: () => manager.peers);
    final cipher = await SameIdentityCipher.fromPrivkey(_privkeyHex);
    _sessions = MeshPeerSessions(
      isar: _isar,
      pubkeyHex: _pubkeyHex,
      privkeyHex: _privkeyHex,
      relations: _relations,
      cipher: cipher,
      router: router,
    );

    // Subscribe before starting the connector so no peer event is missed.
    _peerEventsSub = manager.events.listen(_onPeerEvent);

    // Daily eviction of the ephemeral surrounding cache (startup + hourly).
    _runSurroundingCleanup();
    _surroundingCleanupTimer = Timer.periodic(
      kSurroundingCleanupInterval,
      (_) => _runSurroundingCleanup(),
    );

    // Wire every transport's links into the negotiator's identity proof the same
    // way (LAN sockets + BLE GATT both surface as MeshLinks). BLE is a no-op on
    // platforms without the native channel.
    for (final transport in _transports) {
      _transportLinksSubs.add(
        transport.links.listen((link) => unawaited(manager.onLinkConnected(link))),
      );
    }
    final port = await _connector.start(); // LAN: bound server port for mDNS
    await _bleConnector.start();

    // mDNS: advertise the bound port and dial discovered peers directly (this host
    // owns the bonsoir channel). Best-effort — if discovery can't start, BLE still
    // works on its own.
    try {
      final name = 'uniun-${_randomToken()}';
      _instanceName = name;
      final discovery = LanDiscovery(instanceName: name);
      _discovery = discovery;
      _discoverySub = discovery.peers.listen(_onPeerDiscovered);
      await discovery.start(port: port);
    } catch (e) {
      debugPrint('MESH: LAN discovery unavailable: $e');
    }

    // React to network changes (Wi-Fi switch) by rebinding the LAN layer so sync
    // recovers without an app restart. Seed the baseline IPv4 set first so the
    // first spurious connectivity event doesn't needlessly rebind a fresh start.
    _lanAddrs = await _currentLanAddrs();
    _watchConnectivity();

    // Live propagation: when local content changes (a new note or a bookmark),
    // re-reconcile / re-broadcast to already-connected peers so it appears without
    // an app restart.
    for (final watcher in [
      _isar.noteModels.watchLazy(),
      _isar.savedNoteModels.watchLazy(),
    ]) {
      _changeWatchers.add(watcher.listen((_) => _scheduleResync()));
    }

    debugPrint('MESH: engine started on port $port');
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'shutdown') {
      await _shutdown();
    }
    return null;
  }

  /// Public teardown for the inline (iOS/macOS, main-isolate) host. On Android the
  /// native foreground service triggers `_shutdown` via [_engineChannel] instead.
  Future<void> shutdown() => _shutdown();

  void _watchConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      // A Wi-Fi switch fires a burst (wifi → none → wifi); debounce so we settle
      // on the final interface before rebinding, and rebind only once.
      _lanRestartDebounce?.cancel();
      _lanRestartDebounce =
          Timer(const Duration(milliseconds: 1500), () async {
        final addrs = await _currentLanAddrs();
        if (addrs.isEmpty) return; // no LAN yet — wait for the next event
        if (setEquals(addrs, _lanAddrs)) return; // same network — nothing to do
        _lanAddrs = addrs;
        await _restartLan();
      });
    });
  }

  /// The device's current non-loopback IPv4 addresses — the source of truth for
  /// "did the network actually change", independent of connectivity-type events.
  Future<Set<String>> _currentLanAddrs() async {
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      return ifaces.expand((i) => i.addresses).map((a) => a.address).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Rebinds the LAN transport after a network change, in place (no app restart):
  /// stop the now-dead bonsoir discovery, rebind the TCP server on the new
  /// interface, reset the dial-once dedupe, and re-advertise under a FRESH instance
  /// name so peers that didn't change network treat us as a newly-arrived peer
  /// (getting past their own dial-once set). The dead LAN sockets self-evict when
  /// their reads error; fresh discovery + dialing then reconnects.
  Future<void> _restartLan() async {
    if (_shuttingDown || _lanRestarting) return;
    _lanRestarting = true;
    try {
      await _discoverySub?.cancel();
      _discoverySub = null;
      await _discovery?.stop();
      _discovery = null;
      _dialedPeers.clear();

      final port = await _connector.restartServer();

      final name = 'uniun-${_randomToken()}';
      _instanceName = name;
      final discovery = LanDiscovery(instanceName: name);
      _discovery = discovery;
      _discoverySub = discovery.peers.listen(_onPeerDiscovered);
      await discovery.start(port: port);
      debugPrint('MESH: LAN rebound after network change → port $port');
    } catch (e) {
      debugPrint('MESH: LAN rebind failed: $e');
    } finally {
      _lanRestarting = false;
    }
  }

  // Directional dialing: only the higher-named instance dials; the other accepts.
  // Guarantees one stable connection (no cross-dial race).
  void _onPeerDiscovered(LanPeerEndpoint endpoint) {
    final name = _instanceName;
    if (name == null) return;
    if (name.compareTo(endpoint.name) <= 0) return;
    if (!_dialedPeers.add(endpoint.name)) return; // dedupe repeated resolutions
    unawaited(_connector.dial(endpoint.host, endpoint.port));
  }

  void _onPeerEvent(MeshPeerEvent event) {
    if (event.change == MeshPeerChange.removed) {
      _sessions?.onPeerRemoved(event.peer.pubkey);
      unawaited(_deletePeerRow(event.peer.pubkey));
      return;
    }
    // Added or link-upgraded: record the peer for the UI count and (re)start its
    // sync/surrounding session (delegated to MeshPeerSessions).
    unawaited(_upsertPeerRow(event.peer));
    debugPrint('MESH: peer ${event.peer.pubkey.substring(0, 8)}… '
        'mode=${event.peer.mode.name} → '
        '${event.peer.mode == PeerMode.sameIdentity ? "sync" : "surrounding"}');
    _sessions?.onPeerAdded(event.peer);
  }

  Future<void> _upsertPeerRow(MeshPeer peer) async {
    await _isar.writeTxn(() async {
      await _isar.meshPeerStateModels.put(
        MeshPeerStateModel()
          ..pubkeyHex = peer.pubkey
          ..mode = peer.mode.name
          ..transportKind = peer.activeLink.transportKind.name
          ..connectedAt = DateTime.now(),
      );
    });
  }

  Future<void> _deletePeerRow(String pubkey) async {
    await _isar.writeTxn(() async {
      await _isar.meshPeerStateModels
          .filter()
          .pubkeyHexEqualTo(pubkey)
          .deleteAll();
    });
  }

  void _scheduleResync() {
    _resyncDebounce?.cancel();
    _resyncDebounce = Timer(const Duration(seconds: 2), _resyncAllPeers);
  }

  void _resyncAllPeers() {
    final manager = _manager;
    if (manager == null) return;
    _sessions?.resyncAll(manager.peers);
  }

  void _runSurroundingCleanup() {
    final cutoff = DateTime.now().subtract(kSurroundingRetention);
    final cleanup = SurroundingCleanup(_isar);
    unawaited(cleanup.evictFirstSeenBefore(cutoff));
    // Expire user-deletion tombstones on the same 1-day TTL as the cache.
    unawaited(cleanup.evictTombstonesBefore(cutoff));
  }

  Future<void> _shutdown() async {
    if (_shuttingDown) return;
    _shuttingDown = true;

    _surroundingCleanupTimer?.cancel();
    _resyncDebounce?.cancel();
    _lanRestartDebounce?.cancel();
    await _connectivitySub?.cancel();
    await _discoverySub?.cancel();
    await _discovery?.stop();
    for (final sub in _changeWatchers) {
      await sub.cancel();
    }
    _changeWatchers.clear();
    for (final sub in _transportLinksSubs) {
      await sub.cancel();
    }
    _transportLinksSubs.clear();
    for (final transport in _transports) {
      await transport.stop();
    }
    await _peerEventsSub?.cancel();
    _sessions?.dispose();
    _sessions = null;
    await _manager?.dispose();

    // Clear our peer-count rows so the UI mirror is correct after stop.
    await _isar.writeTxn(() async {
      await _isar.meshPeerStateModels.clear();
    });
    if (ownsIsar) await _isar.close(); // never close the app's shared Isar (inline)
    debugPrint('MESH: engine stopped');
  }

  static String _randomToken() {
    final rng = Random.secure();
    return List<int>.generate(4, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
