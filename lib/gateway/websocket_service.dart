import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/enum/relay_status.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/dm/encrypted_dm_model.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/data/models/relay_model.dart';
import 'package:uniun/data/models/channel_message_model.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:nip77/nip77.dart';

/// Manages a single WebSocket connection to one Nostr relay.
///
/// Responsibilities:
///  - Maintain a persistent connection with exponential-backoff reconnect.
///  - Maintain an [_lastSentQueueId] cursor into [EventQueueModel]; query the
///    next unsent item, send it, then wait for the relay's ["OK"] response
///    before advancing the cursor.
///  - Receive incoming Nostr events and write them directly to [NoteModel].
///  - Update [RelayModel.status] on every connection state change.
class WebSocketService {
  /// NIP-01 [REQ] id for followed-note thread refs (`#e` = followed root ids).
  static const _followedNoteRefsSubscriptionId = 'followed_note_refs';

  static const _dmSubscriptionId = 'dms';
  static const _kind0SubscriptionId = 'profiles';
  static const _channelSubscriptionId = 'channels';

  final String url;
  final bool read;
  final bool write;
  final Isar _isar;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<void>? _missingPubkeysWatcher;

  /// Isar autoincrement id of the last successfully ACK'd queue item.
  /// The service sends items with id > [_lastSentQueueId].
  int _lastSentQueueId;

  int _reconnectAttempt = 0;
  bool _isConnected = false;
  bool _disposed = false;
  Timer? _reconnectTimer;

  /// eventId of the event currently in-flight (sent, waiting for OK).
  String? _pendingEventId;

  /// EventQueueModel.id of the event currently in-flight.
  int? _pendingQueueId;

  final String? activePubkey;

  final void Function(RelayStatus)? onStatusChanged;
  final Future<List<String>?> Function(EventQueueModel)? resolveTargets;

  WebSocketService({
    required this.url,
    required this.read,
    required this.write,
    required Isar isar,
    required int startFromQueueId,
    this.activePubkey,
    this.onStatusChanged,
    this.resolveTargets,
  }) : _isar = isar,
       _lastSentQueueId = startFromQueueId;

  bool get isConnected => _isConnected;

  // ── Connection lifecycle ───────────────────────────────────────────────────

  void connect() {
    if (_disposed) return;
    _updateStatus(RelayStatus.reconnecting);
    try {
      _socket = WebSocketChannel.connect(Uri.parse(url));

      // Wait for TCP/WebSocket readiness before marking connected.
      // This prevents "connection refused" from surfacing as an unhandled error.
      _socket!.ready
          .then((_) {
            if (_disposed) return;
            _socketSub = _socket!.stream.listen(
              _onMessage,
              onError: (_) => _scheduleReconnect(),
              onDone: _scheduleReconnect,
              cancelOnError: true,
            );
            _isConnected = true;
            _reconnectAttempt = 0;
            _updateStatus(RelayStatus.connected);
            _ensureMissingPubkeysWatcher();
            unawaited(_performInitialSyncs());
            _processSendQueue();
          })
          .catchError((_) {
            _scheduleReconnect();
          });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  /// Sends [REQ] for kind1 notes (NIP-01). Live matching [EVENT]s follow until [CLOSE].
  Future<void> _performInitialSyncs() async {
    if (!read || _disposed || _socket == null) return;

    final client = Nip77Client(relayUrl: url);
    bool nip77Connected = false;
    try {
      print("NIP-77: Connecting to $url for initial syncs...");
      await client.connect();
      nip77Connected = true;
      print("NIP-77: Connected successfully to $url");
    } catch (e) {
      print("NIP-77: Connect failed for $url: $e");
    }

    // 2. DMs
    if (activePubkey != null) {
      await _syncOrFallback(client, nip77Connected, _dmSubscriptionId, {
        'kinds': [1059],
        '#p': [activePubkey],
      });
    }

    // 3. Profiles
    final missing = await _isar.missingProfilePubkeyModels.where().findAll();
    if (missing.isNotEmpty) {
      await _syncOrFallback(client, nip77Connected, _kind0SubscriptionId, {
        'kinds': [0],
        'authors': missing.map((m) => m.pubkey).toList(),
      });
    }

    // 4. Followed Notes
    final followed = await _isar.followedNoteModels.where().findAll();
    if (followed.isNotEmpty) {
      final eRefs = followed.map((f) => f.eventId).toList();
      await _syncOrFallback(
        client,
        nip77Connected,
        _followedNoteRefsSubscriptionId,
        {
          'kinds': [1],
          '#e': eRefs,
        },
      );
    }

    // 5. Channels — [ChannelModel] presence means subscribed locally
    final channels = await _isar.channelModels.where().findAll();
    if (channels.isNotEmpty) {
      final channelIds = channels.map((c) => c.channelId).toList();

      // Sync 41 and 42 via NIP-77 (#e references channelId)
      await _syncOrFallback(client, nip77Connected, _channelSubscriptionId, {
        'kinds': [41, 42],
        '#e': channelIds,
      });

      // Fetch 40 directly since channelId == eventId for kind 40 (no #e tag needed)
      _socket!.sink.add(
        jsonEncode([
          'REQ',
          '${_channelSubscriptionId}_info',
          {
            'kinds': [40],
            'ids': channelIds,
          },
        ]),
      );
    }

    if (nip77Connected) {
      await client.disconnect();
    }
  }

  Future<void> _syncOrFallback(
    Nip77Client client,
    bool nip77Connected,
    String subId,
    Map<String, dynamic> filter,
  ) async {
    if (!read || _disposed || _socket == null || !_isConnected) return;

    bool useFallback = !nip77Connected;

    if (nip77Connected) {
      try {
        print("NIP-77: --- Syncing subscription: $subId ---");
        print("NIP-77: Filter: $filter");
        final myEvents = await _getLocalEventIdsForFilter(filter);
        print("NIP-77: Found ${myEvents.length} local events for $subId");

        final syncResult = await client.syncEvents(
          myEvents: myEvents,
          filter: filter,
        );

        print(
          "NIP-77: Sync complete for $subId. Need: ${syncResult.needIds.length}, Have (un-uploaded): ${syncResult.haveIds.length}",
        );

        if (syncResult.needIds.isNotEmpty) {
          final reqJson = jsonEncode([
            'REQ',
            '${subId}_missing',
            {'ids': syncResult.needIds},
          ]);
          print("NIP-77: Sending REQ for missing events: $reqJson");
          _socket!.sink.add(reqJson);
        }
      } catch (e) {
        print("NIP-77: Sync failed for $subId: $e");
        useFallback = true;
      }
    }

    if (_disposed || _socket == null || !_isConnected) return;

    if (useFallback) {
      final fallbackReq = jsonEncode(['REQ', subId, filter]);
      print("NIP-77: Fallback standard REQ for $subId: $fallbackReq");
      _socket!.sink.add(fallbackReq);
    } else {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final liveFilter = Map<String, dynamic>.from(filter);
      liveFilter['since'] = nowSec;
      final liveReq = jsonEncode(['REQ', subId, liveFilter]);
      print("NIP-77: Live streaming REQ for $subId: $liveReq");
      _socket!.sink.add(liveReq);
    }
  }

  Future<Map<String, int>> _getLocalEventIdsForFilter(
    Map<String, dynamic> filter,
  ) async {
    final Map<String, int> myEvents = {};
    final kindsList = filter['kinds'] as List<dynamic>?;
    if (kindsList == null || kindsList.isEmpty) return myEvents;

    for (final kind in kindsList) {
      if (kind == 1) {
        final ids = await _isar.noteModels.where().eventIdProperty().findAll();
        for (final id in ids) {
          myEvents[id] = 0;
        }
      } else if (kind == 1059) {
        final ids = await _isar.encryptedDmModels
            .where()
            .eventIdProperty()
            .findAll();
        for (final id in ids) {
          myEvents[id] = 0;
        }
      } else if (kind == 41) {
        // We track the last meta event in ChannelModel, but since NIP-77 expects all event IDs
        // for range reconciliation, we will only add the one we have tracked.
        // It might result in fetching older 41s we missed, which is fine.
        final channels = await _isar.channelModels.where().findAll();
        for (final ch in channels) {
          if (ch.lastMetaEvent != null) {
            myEvents[ch.lastMetaEvent!] = 0;
          }
        }
      } else if (kind == 42) {
        final ids = await _isar.channelMessageModels
            .where()
            .eventIdProperty()
            .findAll();
        for (final id in ids) {
          myEvents[id] = 0;
        }
      } else if (kind == 0) {
        // Rarely have local missing profiles stored, but if we do, skip passing eventId since ProfileModel doesn't store eventId.
      }
    }
    return myEvents;
  }

  Future<void> _subscribeKind0Profiles() async {
    if (!read || _disposed || _socket == null) return;
    _socket!.sink.add(jsonEncode(['CLOSE', _kind0SubscriptionId]));
    final missing = await _isar.missingProfilePubkeyModels.where().findAll();
    if (missing.isEmpty) return;

    _socket!.sink.add(
      jsonEncode([
        'REQ',
        _kind0SubscriptionId,
        {
          'kinds': [0],
          'authors': missing.map((m) => m.pubkey).toList(),
        },
      ]),
    );
  }

  void _ensureMissingPubkeysWatcher() {
    if (_missingPubkeysWatcher != null) return;
    _missingPubkeysWatcher = _isar.missingProfilePubkeyModels
        .watchLazy()
        .listen((_) => unawaited(_subscribeKind0Profiles()));
  }

  /// Refreshes the `#e`-filtered [REQ] for all rows in [FollowedNoteModel].
  ///
  /// Called after connect and whenever [CentralRelayManager] observes follow
  /// list changes. Safe to call when not yet connected (no-op).
  Future<void> resyncFollowedNoteSubscriptions() async {
    await _subscribeFollowedNoteRefs();
  }

  Future<void> _subscribeFollowedNoteRefs() async {
    if (!read || _disposed || _socket == null || !_isConnected) return;

    _socket!.sink.add(jsonEncode(['CLOSE', _followedNoteRefsSubscriptionId]));

    final followed = await _isar.followedNoteModels.where().findAll();
    if (followed.isEmpty) return;

    final eRefs = followed.map((f) => f.eventId).toList();
    final filter = {
      'kinds': [1],
      '#e': eRefs,
    };

    final client = Nip77Client(relayUrl: url);
    bool connected = false;
    try {
      await client.connect();
      connected = true;
    } catch (_) {}

    await _syncOrFallback(
      client,
      connected,
      _followedNoteRefsSubscriptionId,
      filter,
    );

    if (connected) await client.disconnect();
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _missingPubkeysWatcher?.cancel();
    _missingPubkeysWatcher = null;
    _socketSub?.cancel();
    _socket?.sink.close();
    _isConnected = false;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _isConnected = false;
    _pendingEventId = null;
    _pendingQueueId = null;
    _updateStatus(RelayStatus.disconnected);
    _socketSub?.cancel();
    _socket?.sink.close();

    final delaySec = min(pow(2, _reconnectAttempt).toInt(), 60);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }

  // ── Outbound — send queue ──────────────────────────────────────────────────

  /// Called by [CentralRelayManager] when a new item is enqueued.
  void onNewQueueItem() => _processSendQueue();

  /// Called by [CentralRelayManager] when [FollowedNoteModel] rows change.
  void onFollowedNotesChanged() => unawaited(_subscribeFollowedNoteRefs());

  /// Called by [CentralRelayManager] when [ChannelModel] rows change.
  void onChannelSubscriptionsChanged() => unawaited(_resubscribeChannels());

  Future<void> _resubscribeChannels() async {
    if (!read || _disposed || _socket == null || !_isConnected) return;

    _socket!.sink.add(jsonEncode(['CLOSE', _channelSubscriptionId]));
    _socket!.sink.add(jsonEncode(['CLOSE', '${_channelSubscriptionId}_info']));

    final channelRows = await _isar.channelModels.where().findAll();
    if (channelRows.isEmpty) return;

    final channelIds = channelRows.map((c) => c.channelId).toList();

    final client = Nip77Client(relayUrl: url);
    bool connected = false;
    try {
      await client.connect();
      connected = true;
    } catch (_) {}

    await _syncOrFallback(client, connected, _channelSubscriptionId, {
      'kinds': [41, 42],
      '#e': channelIds,
    });

    if (connected) {
      await client.disconnect();
    }

    _socket!.sink.add(
      jsonEncode([
        'REQ',
        '${_channelSubscriptionId}_info',
        {
          'kinds': [40],
          'ids': channelIds,
        },
      ]),
    );
  }

  Future<void> _processSendQueue() async {
    // Guard: only send if this relay is a write relay, connected, and idle.
    if (!write || !_isConnected || _pendingEventId != null) return;

    final next = await _isar.eventQueueModels
        .where()
        .idGreaterThan(_lastSentQueueId)
        .findFirst();

    if (next == null) return;

    if (resolveTargets != null) {
      final targets = await resolveTargets!(next);
      if (targets != null && !targets.contains(url)) {
        _lastSentQueueId = next.id;
        _processSendQueue();
        return;
      }
    }

    _pendingEventId = next.eventId;
    _pendingQueueId = next.id;
    _socket!.sink.add(next.toSerializedRelayMessage());
  }

  // ── Inbound — relay messages ───────────────────────────────────────────────

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    List<dynamic> data;
    try {
      data = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return;
    }
    if (data.isEmpty) return;

    final type = data[0] as String;
    switch (type) {
      case 'OK':
        _handleOk(data);
        break;
      case 'EVENT':
        if (read && data.length >= 3) {
          final eventMap = data[2] as Map<String, dynamic>;
          unawaited(_trackMissingProfilePubkey(eventMap));
          final kind = eventMap['kind'] as int?;
          if (kind == 1) {
            unawaited(_handleIncomingKind1Event(eventMap));
          } else if (kind == 0) {
            unawaited(_storeIncomingKind0Profile(eventMap));
          } else if (kind == 1059) {
            unawaited(_storeEncryptedDm(eventMap));
          } else if (kind == 40) {
            unawaited(_handleKind40(eventMap));
          } else if (kind == 41) {
            unawaited(_handleKind41(eventMap));
          } else if (kind == 42) {
            unawaited(_handleKind42(eventMap));
          }
        }
        break;
      case 'EOSE':
        // End of stored events — no action needed in v1.
        break;
      case 'NOTICE':
        // Relay notice — silently ignored in v1.
        break;
    }
  }

  Future<void> _handleOk(List<dynamic> data) async {
    if (data.length < 3) return;
    final eventId = data[1] as String?;
    final accepted = data[2] as bool?;
    if (eventId == null || accepted == null) return;
    if (eventId != _pendingEventId) return;

    if (accepted) {
      // Increment sentCount so CentralRelayManager can dequeue when threshold met.
      await _isar.writeTxn(() async {
        final item = await _isar.eventQueueModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (item != null) {
          item.sentCount++;
          await _isar.eventQueueModels.put(item);
        }
      });
      if (_pendingQueueId != null) {
        _lastSentQueueId = _pendingQueueId!;
      }
    }

    // Whether accepted or rejected, release the pending slot and move on.
    _pendingEventId = null;
    _pendingQueueId = null;
    _processSendQueue();
  }

  Future<void> _handleIncomingKind1Event(Map<String, dynamic> event) async {
    await _storeIncomingEvent(event);
    await _bumpFollowedReferenceCountsIfNeeded(event);
  }

  /// Parses an incoming Nostr event map and persists it to [NoteModel].
  ///
  /// Idempotent — skips if [eventId] already exists.
  /// Only handles Kind 1 (short text notes) in v1.
  Future<void> _storeIncomingEvent(Map<String, dynamic> event) async {
    final kind = event['kind'] as int?;
    if (kind != 1) return;

    final eventId = event['id'] as String?;
    if (eventId == null) return;

    final model = _parseNoteModel(event);
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.noteModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await _isar.noteModels.put(model);
        // Increment direct parent + mention-refs. Exclude root-tag when it
        // differs from replyToEventId so nested thread replies don't inflate
        // the root note's count.
        final toIncrement = <String>{};
        if (model.replyToEventId != null) {
          toIncrement.add(model.replyToEventId!);
        }
        for (final ref in model.eTagRefs) {
          if (ref != model.rootEventId && ref != model.replyToEventId) {
            toIncrement.add(ref);
          }
        }
        for (final refId in toIncrement) {
          final ref = await _isar.noteModels
              .where()
              .eventIdEqualTo(refId)
              .findFirst();
          if (ref != null) {
            ref.cachedReplyCount++;
            await _isar.noteModels.put(ref);
          }
        }
      });
    } catch (_) {
      // Another concurrent relay delivery may have inserted the same eventId.
      return;
    }
    // Isar watcher in Isolate 1 fires automatically — Flutter UI updates.
  }

  Future<void> _storeEncryptedDm(Map<String, dynamic> event) async {
    final eventId = event['id'] as String?;
    if (eventId == null) return;

    final rawTags = (event['tags'] as List<dynamic>? ?? []);
    String? pTagRef;
    for (final tag in rawTags) {
      if (tag is List && tag.length >= 2 && tag[0] == 'p') {
        pTagRef = tag[1] as String;
        break;
      }
    }

    if (pTagRef == null) return;

    final model = EncryptedDmModel(
      eventId: eventId,
      sig: event['sig'] as String? ?? '',
      authorPubkey: event['pubkey'] as String? ?? '',
      pTagRef: pTagRef,
      content: event['content'] as String? ?? '',
      kind: event['kind'] as int? ?? 1059,
      created: DateTime.fromMillisecondsSinceEpoch(
        (event['created_at'] as int? ?? 0) * 1000,
      ),
    );

    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.encryptedDmModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await _isar.encryptedDmModels.put(model);
      });
    } catch (_) {
      // Duplicate write race from concurrent relay deliveries.
      return;
    }
  }

  Future<void> _handleKind40(Map<String, dynamic> event) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final createdAt = event['created_at'] as int?;
    if (eventId == null || pubkey == null || createdAt == null) return;

    final contentStr = event['content'] as String? ?? '{}';
    Map<String, dynamic> metadata;
    try {
      metadata = jsonDecode(contentStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await _isar.writeTxn(() async {
      final channel = await _isar.channelModels
          .where()
          .channelIdEqualTo(eventId)
          .findFirst();
      if (channel == null) return; // Only update existing channels

      channel.creatorPubKey = pubkey;
      channel.createdAt = createdAt;
      channel.name = metadata['name'] as String? ?? channel.name;
      channel.about = metadata['about'] as String? ?? channel.about;
      channel.picture = metadata['picture'] as String? ?? channel.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        channel.relays = relays.map((e) => e.toString()).toList();
      }

      await _isar.channelModels.put(channel);
    });
  }

  Future<void> _handleKind41(Map<String, dynamic> event) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final createdAt = event['created_at'] as int?;
    if (eventId == null || pubkey == null || createdAt == null) return;

    final tags = event['tags'] as List<dynamic>? ?? [];
    String? channelId;
    for (final tag in tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e') {
        channelId = tag[1] as String?;
        break; // first e tag should be the channel id
      }
    }
    if (channelId == null) return;

    final contentStr = event['content'] as String? ?? '{}';
    Map<String, dynamic> metadata;
    try {
      metadata = jsonDecode(contentStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    await _isar.writeTxn(() async {
      final channel = await _isar.channelModels
          .where()
          .channelIdEqualTo(channelId!)
          .findFirst();
      if (channel == null) return; // Ignore if we don't know the channel

      // Only accept metadata updates from the original creator
      if (channel.creatorPubKey != pubkey) return;

      // Only accept if it's newer than the last known update
      if (createdAt <= channel.updatedAt) return;

      channel.name = metadata['name'] as String? ?? channel.name;
      channel.about = metadata['about'] as String? ?? channel.about;
      channel.picture = metadata['picture'] as String? ?? channel.picture;

      final relays = metadata['relays'];
      if (relays is List) {
        channel.relays = relays.map((e) => e.toString()).toList();
      }

      channel.updatedAt = createdAt;
      channel.lastMetaEvent = eventId;

      await _isar.channelModels.put(channel);
    });
  }

  Future<void> _handleKind42(Map<String, dynamic> event) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final sig = event['sig'] as String?;
    final content = event['content'] as String?;
    final createdAtInt = event['created_at'] as int?;

    if (eventId == null ||
        pubkey == null ||
        sig == null ||
        content == null ||
        createdAtInt == null)
      return;

    final created = DateTime.fromMillisecondsSinceEpoch(createdAtInt * 1000);

    final tags = event['tags'] as List<dynamic>? ?? [];
    String? channelId;
    String? rootEventId;
    String? replyEventId;
    final List<String> eTagRefs = [];

    for (final tag in tags) {
      if (tag is List && tag.isNotEmpty && tag[0] == 'e') {
        final eRef = tag[1] as String?;
        if (eRef != null) {
          eTagRefs.add(eRef);
          final marker = tag.length > 3 ? tag[3] as String? : null;
          if (marker == 'root') {
            channelId = eRef;
          } else if (marker == 'reply') {
            replyEventId = eRef;
          }
        }
      }
    }

    // Fallback if markers are not properly set (NIP-10 legacy)
    if (channelId == null && eTagRefs.isNotEmpty) {
      channelId = eTagRefs.first;
    }
    if (replyEventId == null && eTagRefs.length > 1) {
      replyEventId = eTagRefs.last;
    }

    if (channelId == null) return;

    final model = ChannelMessageModel()
      ..eventId = eventId
      ..channelId = channelId
      ..sig = sig
      ..authorPubkey = pubkey
      ..content = content
      ..eTagRefs = eTagRefs
      ..pTagRefs = []
      ..rootEventId = channelId
      ..replyToEventId = replyEventId
      ..created = created;

    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.channelMessageModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await _isar.channelMessageModels.put(model);
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _storeIncomingKind0Profile(Map<String, dynamic> event) async {
    final pubkey = event['pubkey'] as String?;
    final createdAtSec = event['created_at'] as int?;
    if (pubkey == null || pubkey.isEmpty || createdAtSec == null) return;

    Map<String, dynamic> metadata;
    try {
      metadata =
          jsonDecode(event['content'] as String? ?? '') as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final incomingUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
      createdAtSec * 1000,
    );
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.profileModels
            .where()
            .pubkeyEqualTo(pubkey)
            .findFirst();
        if (existing != null &&
            incomingUpdatedAt.isBefore(existing.updatedAt)) {
          return;
        }

        final model = existing ?? ProfileModel();
        model.pubkey = pubkey;
        model.name =
            metadata['display_name'] as String? ?? metadata['name'] as String?;
        model.username = metadata['name'] as String?;
        model.about = metadata['about'] as String?;
        model.avatarUrl = metadata['picture'] as String?;
        model.nip05 = metadata['nip05'] as String?;
        model.updatedAt = incomingUpdatedAt;
        model.lastSeenAt = existing?.lastSeenAt;

        await _isar.profileModels.put(model);

        final missing = await _isar.missingProfilePubkeyModels
            .where()
            .pubkeyEqualTo(pubkey)
            .findFirst();
        if (missing != null) {
          await _isar.missingProfilePubkeyModels.delete(missing.id);
        }
      });
    } catch (_) {
      // Duplicate upsert race from concurrent kind-0 deliveries.
      return;
    }
  }

  Future<void> _trackMissingProfilePubkey(Map<String, dynamic> event) async {
    final pubkey = event['pubkey'] as String?;
    if (pubkey == null || pubkey.isEmpty) return;

    final existingProfile = await _isar.profileModels
        .where()
        .pubkeyEqualTo(pubkey)
        .findFirst();
    if (existingProfile != null) return;
    try {
      await _isar.writeTxn(() async {
        // Keep check+insert in one write transaction to avoid races when
        // duplicate relay deliveries arrive concurrently.
        final existingMissing = await _isar.missingProfilePubkeyModels
            .where()
            .pubkeyEqualTo(pubkey)
            .findFirst();
        if (existingMissing != null) return;

        final row = MissingProfilePubkeyModel()
          ..pubkey = pubkey
          ..firstSeenAt = DateTime.now();
        await _isar.missingProfilePubkeyModels.put(row);
      });
    } catch (_) {
      // Best-effort tracking only. If another concurrent writer inserted the
      // same pubkey first (unique index), we can safely ignore.
    }
  }

  Future<void> _bumpFollowedReferenceCountsIfNeeded(
    Map<String, dynamic> event,
  ) async {
    final kind = event['kind'] as int?;
    if (kind != 1) return;

    final incomingId = event['id'] as String?;
    if (incomingId == null || incomingId.isEmpty) return;

    final eRefs = _extractEtagIdsFromEventMap(event);
    if (eRefs.isEmpty) return;

    final followed = await _isar.followedNoteModels.where().findAll();
    if (followed.isEmpty) return;

    final followedRoots = followed.map((f) => f.eventId).toSet();
    final refsToIncrement = <String>{};

    for (final ref in eRefs) {
      if (!followedRoots.contains(ref)) continue;
      if (ref == incomingId) continue;
      refsToIncrement.add(ref);
    }
    if (refsToIncrement.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final ref in refsToIncrement) {
        final fresh = await _isar.followedNoteModels
            .where()
            .eventIdEqualTo(ref)
            .findFirst();
        if (fresh == null) continue;
        fresh.newReferenceCount = fresh.newReferenceCount + 1;
        await _isar.followedNoteModels.put(fresh);
      }
    });
  }

  List<String> _extractEtagIdsFromEventMap(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? []);
    final out = <String>[];
    for (final rawTag in rawTags) {
      if (rawTag is! List || rawTag.isEmpty) continue;
      final tagName = rawTag[0] as String?;
      if (tagName != 'e' || rawTag.length < 2) continue;
      final id = rawTag[1] as String?;
      if (id == null || id.isEmpty) continue;
      out.add(id);
    }
    return out;
  }

  NoteModel _parseNoteModel(Map<String, dynamic> event) {
    final rawTags = (event['tags'] as List<dynamic>? ?? []);

    String? rootEventId;
    String? replyToEventId;
    final eTagRefs = <String>[];
    final pTagRefs = <String>[];
    final tTags = <String>[];

    for (final rawTag in rawTags) {
      if (rawTag is! List || rawTag.isEmpty) continue;
      final tagName = rawTag[0] as String?;
      if (tagName == null || rawTag.length < 2) continue;

      switch (tagName) {
        case 'e':
          final tagId = rawTag[1] as String;
          eTagRefs.add(tagId);
          if (rawTag.length > 3) {
            final marker = rawTag[3] as String?;
            if (marker == 'root') rootEventId = tagId;
            if (marker == 'reply') replyToEventId = tagId;
          }
        case 'p':
          pTagRefs.add(rawTag[1] as String);
        case 't':
          tTags.add(rawTag[1] as String);
      }
    }

    final content = event['content'] as String? ?? '';
    final createdAtSec = event['created_at'] as int? ?? 0;

    return NoteModel(
      eventId: event['id'] as String,
      sig: event['sig'] as String? ?? '',
      authorPubkey: event['pubkey'] as String? ?? '',
      content: content,
      type: NoteType.text,
      eTagRefs: eTagRefs,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      pTagRefs: pTagRefs,
      tTags: tTags,
      created: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000),
      isSeen: false,
    );
  }

  // ── Status tracking ────────────────────────────────────────────────────────

  void _updateStatus(RelayStatus status) {
    onStatusChanged?.call(status);
  }
}
