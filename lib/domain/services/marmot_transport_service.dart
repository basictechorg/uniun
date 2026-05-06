import 'dart:async';
import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/encrypted_message_model.dart';
import 'package:uniun/data/models/private_channel_join_request_model.dart';
import 'package:uniun/data/models/private_channel_message_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/domain/services/marmot_mls_service.dart';

import 'package:injectable/injectable.dart';

@lazySingleton
class MarmotTransportService {
  final Isar _isar;
  final MarmotMlsService _mlsService;
  StreamSubscription<void>? _subscription;

  MarmotTransportService(this._isar, this._mlsService);

  void start() {
    _processPendingMessages();
    _subscription = _isar.encryptedMessageModels.watchLazy().listen((_) {
      _processPendingMessages();
    });
  }

  void stop() {
    _subscription?.cancel();
  }

  Future<PrivateChannelModel?> _findChannel(String groupId) {
    return _isar.privateChannelModels.where().groupIdEqualTo(groupId).findFirst();
  }

  Future<void> _processPendingMessages() async {
    final pending = await _isar.encryptedMessageModels.where().findAll();
    if (pending.isEmpty) return;

    for (final encrypted in pending) {
      try {
        if (encrypted.kind == 9024) {
          final joinedMlsGroupIdB64 = await _mlsService.joinGroupFromWelcome(
            welcomeB64: encrypted.encryptedPayload,
          );
          final channel = await _findChannel(encrypted.groupId);
          if (channel == null) {
            continue;
          }
          await _isar.writeTxn(() async {
            channel.mlsGroupId = joinedMlsGroupIdB64;
            await _isar.privateChannelModels.put(channel);
            await _isar.encryptedMessageModels.delete(encrypted.id);
          });
          continue;
        }

        if (encrypted.kind == 9025) {
          final channel = await _findChannel(encrypted.groupId);
          if (channel == null || channel.mlsGroupId.isEmpty) {
            // Wait until welcome has populated mlsGroupId.
            continue;
          }
          await _mlsService.processProtocolMessage(
            groupId: channel.mlsGroupId,
            base64Payload: encrypted.encryptedPayload,
            groupIdIsBase64: true,
          );
          await _isar.writeTxn(() async {
            await _isar.encryptedMessageModels.delete(encrypted.id);
          });
          continue;
        }

        if (encrypted.kind == 9022) {
          await _isar.writeTxn(() async {
            await _isar.encryptedMessageModels.delete(encrypted.id);
          });
          continue;
        }

        final channel = await _findChannel(encrypted.groupId);
        if (channel == null || channel.mlsGroupId.isEmpty) {
          continue;
        }

        final decryptedBytes = await _mlsService.decryptMessage(
          groupId: channel.mlsGroupId,
          base64Payload: encrypted.encryptedPayload,
          groupIdIsBase64: true,
        );

        final decryptedMsg = PrivateChannelMessageModel()
          ..eventId = encrypted.eventId
          ..groupId = encrypted.groupId
          ..senderPubkey = encrypted.senderPubkey
          ..decryptedContent = utf8.decode(decryptedBytes)
          ..eTagRefs = []
          ..pTagRefs = []
          ..timestamp = encrypted.timestamp;

        await _isar.writeTxn(() async {
          await _isar.privateChannelMessageModels.put(decryptedMsg);
          await _isar.encryptedMessageModels.delete(encrypted.id);
        });
      } catch (e) {
        // Leave in queue if epoch mismatch or other retryable error.
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds an [EventQueueModel] from a fully-signed [Event].
  ///
  /// For private channel events, the full signed event JSON is stored in
  /// [content] so [WebSocketService] can send it verbatim (preserving the
  /// `["h", groupId]` tag via `toRawRelayMessage()`).
  EventQueueModel _buildQueueEntry(Event event) {
    return EventQueueModel()
      ..eventId = event.id
      ..kind = event.kind
      ..content = jsonEncode(event.toJson()) // full signed event JSON
      ..authorPubkey = event.pubkey
      ..sig = event.sig
      ..eTagRefs = []
      ..pTagRefs = []
      ..tTags = []
      ..sentCount = 0
      ..created = DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)
      ..enqueuedAt = DateTime.now();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a NIP-29 private channel.
  ///
  /// Signs a kind-9002 event. Its [event.id] becomes the [groupId] so the
  /// server can identify the group from the creation event alone. All
  /// subsequent events for this channel use `["h", groupId]` tag.
  ///
  /// Returns the generated [groupId] (= event id of the creation event).
  Future<String> createChannel({
    required String privkeyHex, // hex private key for signing
    required String authorPubkey,
    required String name,
    required String description,
    required List<String> relays,
  }) async {
    // 1. Initialize local MLS group state
    final createResult = await _mlsService.createGroup(
      creatorPubkeyHex: authorPubkey,
    );
    final mlsGroupId = base64Encode(createResult.groupId);

    // 2. Sign the channel creation event (kind 9002 — NIP-29 edit-metadata).
    //    No `h` tag here: this IS the creation event, and its id becomes the groupId.
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final event = Event.from(
      privkey: privkeyHex,
      kind: 9002,
      content: jsonEncode({'name': name, 'about': description}),
      tags: [],
      createdAt: createdAt,
    );

    final groupId = event.id; // ← groupId = event id of the creation event

    // 3. Persist locally + queue for relay
    final model = PrivateChannelModel()
      ..groupId = groupId
      ..mlsGroupId = mlsGroupId
      ..name = name
      ..description = description
      ..relays = relays
      ..adminPubkey = authorPubkey;

    await _isar.writeTxn(() async {
      await _isar.privateChannelModels.put(model);
      await _isar.eventQueueModels.put(_buildQueueEntry(event));
    });

    return groupId;
  }

  /// NIP-29 Join Request with MLS KeyPackage embedded in content.
  ///
  /// Saves a local [PrivateChannelModel] stub so [CentralRelayManager] can
  /// route the join event to the correct relays. The stub has an empty
  /// mlsGroupId until the admin sends back the Welcome message.
  Future<void> joinChannel({
    required String groupId,
    required String authorPubkey,
    required String privkeyHex,
    required List<String> relays,
  }) async {
    final keyPackageB64 = await _mlsService.generateKeyPackage(
      pubkeyHex: authorPubkey,
    );

    final event = Event.from(
      privkey: privkeyHex,
      kind: 9021,
      content: keyPackageB64,
      tags: [
        ['h', groupId]
      ],
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Save a local stub so the relay router can find the channel's relays.
    final existing = await _isar.privateChannelModels
        .where()
        .groupIdEqualTo(groupId)
        .findFirst();

    await _isar.writeTxn(() async {
      if (existing == null) {
        final stub = PrivateChannelModel()
          ..groupId = groupId
          ..mlsGroupId = '' // filled in after Welcome is received
          ..name = groupId  // placeholder until metadata synced
          ..description = ''
          ..relays = relays
          ..adminPubkey = '';
        await _isar.privateChannelModels.put(stub);
      } else if (existing.relays.isEmpty && relays.isNotEmpty) {
        existing.relays = relays;
        await _isar.privateChannelModels.put(existing);
      }
      await _isar.eventQueueModels.put(_buildQueueEntry(event));
    });
  }

  /// NIP-29 Leave Request.
  Future<void> leaveChannel({
    required String groupId,
    required String authorPubkey,
    required String privkeyHex,
  }) async {
    final channel = await _findChannel(groupId);

    final event = Event.from(
      privkey: privkeyHex,
      kind: 9022,
      content: '',
      tags: [
        ['h', groupId]
      ],
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    if (channel != null && channel.mlsGroupId.isNotEmpty) {
      try {
        await _mlsService.leaveGroup(
          groupId: channel.mlsGroupId,
          groupIdIsBase64: true,
        );
      } catch (_) {
        // Best effort: continue with local row removal + relay leave event queue.
      }
    }

    await _isar.writeTxn(() async {
      await _isar.eventQueueModels.put(_buildQueueEntry(event));
      await _isar.privateChannelModels.where().groupIdEqualTo(groupId).deleteAll();
    });
  }

  /// Encrypts an application message (kind 9023) and queues it.
  Future<void> sendChannelMessage({
    required String groupId,
    required String content,
    required String authorPubkey,
    required String privkeyHex,
  }) async {
    final channel = await _findChannel(groupId);
    if (channel == null) {
      throw Exception('Private channel not found locally for groupId: $groupId');
    }
    if (channel.mlsGroupId.isEmpty) {
      throw Exception('MLS group is not initialized for groupId: $groupId');
    }

    final encryptedPayload = await _mlsService.encryptMessage(
      groupId: channel.mlsGroupId,
      content: content,
      groupIdIsBase64: true,
    );

    final now = DateTime.now();
    final event = Event.from(
      privkey: privkeyHex,
      kind: 9023,
      content: encryptedPayload,
      tags: [
        ['h', groupId]
      ],
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
    );

    final localMessage = PrivateChannelMessageModel()
      ..eventId = event.id
      ..groupId = groupId
      ..senderPubkey = authorPubkey
      ..decryptedContent = content
      ..eTagRefs = []
      ..pTagRefs = []
      ..timestamp = now;

    await _isar.writeTxn(() async {
      await _isar.privateChannelMessageModels.put(localMessage);
      await _isar.eventQueueModels.put(_buildQueueEntry(event));
    });
  }

  /// Admin approves a join request: publishes MLS Welcome (9024) + Commit (9025).
  Future<void> approveJoinRequest({
    required String groupId,
    required String userKeyPackageB64,
    required String adminPrivkeyHex,
  }) async {
    final channel = await _findChannel(groupId);
    if (channel == null) {
      throw Exception('Private channel not found locally for groupId: $groupId');
    }
    if (channel.mlsGroupId.isEmpty) {
      throw Exception('MLS group is not initialized for groupId: $groupId');
    }

    final addResult = await _mlsService.addMembers(
      groupId: channel.mlsGroupId,
      keyPackagesB64: [userKeyPackageB64],
      groupIdIsBase64: true,
    );

    final welcomeEvent = Event.from(
      privkey: adminPrivkeyHex,
      kind: 9024,
      content: base64Encode(addResult.welcome),
      tags: [
        ['h', groupId]
      ],
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final commitEvent = Event.from(
      privkey: adminPrivkeyHex,
      kind: 9025,
      content: base64Encode(addResult.commit),
      tags: [
        ['h', groupId]
      ],
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    await _isar.writeTxn(() async {
      await _isar.eventQueueModels.putAll([
        _buildQueueEntry(welcomeEvent),
        _buildQueueEntry(commitEvent),
      ]);

      final matchingRequests = await _isar.privateChannelJoinRequestModels
          .where()
          .groupIdEqualTo(groupId)
          .findAll();

      final approvedRequest = matchingRequests
          .where((request) => request.keyPackageB64 == userKeyPackageB64)
          .firstOrNull;

      if (approvedRequest != null) {
        await _isar.privateChannelJoinRequestModels.delete(approvedRequest.id);
      }
    });
  }
}
