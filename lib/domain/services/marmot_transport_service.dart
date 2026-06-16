import 'dart:async';
import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/data/models/encrypted_message_model.dart';
import 'package:uniun/gateway/inbound/missing_profile_tracker.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/private_channel_join_request_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
import 'package:uniun/domain/services/marmot_mls_service.dart';

import 'package:injectable/injectable.dart';

@lazySingleton
class MarmotTransportService {
  final Isar _isar;
  final MarmotMlsService _mlsService;
  final NoteRelationRepository _relations;
  StreamSubscription<void>? _subscription;

  MarmotTransportService(this._isar, this._mlsService, this._relations);

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

        final envelope = _decodeMessageEnvelope(utf8.decode(decryptedBytes));

        final decryptedMsg = NoteModel(
          eventId: encrypted.eventId,
          sig: '',
          authorPubkey: encrypted.senderPubkey,
          content: envelope.content,
          kind: kPrivateChannelKind,
          groupId: encrypted.groupId,
          type: envelope.attachments.any((a) => a.mime.startsWith('image/'))
              ? NoteType.image
              : NoteType.text,
          eTagRefs: envelope.eTagRefs,
          rootEventId: envelope.rootEventId,
          replyToEventId: envelope.replyToEventId,
          pTagRefs: const [],
          tTags: const [],
          created: encrypted.timestamp,
          quoteEventId: envelope.quoteEventId,
          attachments: envelope.attachments,
        );

        await _isar.writeTxn(() async {
          // Own messages are already in the DB from the local send, so a missing
          // row means a genuinely new inbound message → mark it unread.
          final existing = await _isar.noteModels
              .where()
              .eventIdEqualTo(decryptedMsg.eventId)
              .findFirst();
          await _isar.noteModels.put(decryptedMsg);
          if (existing == null) {
            await putUnreadRowInTxn(_isar, decryptedMsg);
          }
          // Reference edges via the shared repo. eTagRefs are currently empty
          // on decrypted MLS payloads, so this is a no-op today, but routes
          // any future NIP-10-style refs through the single edge table.
          final parents = replyEdgeParentIds(
            replyToEventId: null,
            rootEventId: null,
            eTagRefs: decryptedMsg.eTagRefs,
          );
          await _relations.addEdgesInTxn(
            parents: parents,
            childId: decryptedMsg.eventId,
          );
          await _isar.encryptedMessageModels.delete(encrypted.id);
        });
        // Outside the txn — flag the sender for profile fetch if unknown.
        // Profiles subscription will pick this up and fill the username so the
        // NoteCard stops showing the raw pubkey.
        await MissingProfileTracker(_isar)
            .trackPubkey(decryptedMsg.authorPubkey);
      } catch (e) {
        // Leave in queue if epoch mismatch or other retryable error.
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Encodes a message body + its reference ids + NIP-10 threading markers +
  /// NIP-92 imeta attachments into the encrypted MLS payload. Plain text is
  /// sent verbatim when there is no metadata (backward compatible); otherwise
  /// a small JSON envelope carries the e-tag ids (`e`), the root marker
  /// (`r`), the reply marker (`y`), the quote id (`q`), and the imeta list
  /// (`i`). Receiver-side decryption rebuilds `NoteModel.attachments` from
  /// `i`.
  String _encodeMessageEnvelope(
    String content,
    List<String> eTagRefs, {
    String? rootEventId,
    String? replyToEventId,
    String? quoteEventId,
    List<MediaAttachment> attachments = const [],
  }) {
    if (eTagRefs.isEmpty &&
        rootEventId == null &&
        replyToEventId == null &&
        quoteEventId == null &&
        attachments.isEmpty) {
      return content;
    }
    return jsonEncode({
      'c': content,
      'e': eTagRefs,
      if (rootEventId != null) 'r': rootEventId,
      if (replyToEventId != null) 'y': replyToEventId,
      if (quoteEventId != null) 'q': quoteEventId,
      if (attachments.isNotEmpty)
        'i': [
          for (final a in attachments)
            {
              'x': a.sha256,
              'm': a.mime,
              if (a.sizeBytes > 0) 's': a.sizeBytes,
              if (a.url != null) 'u': a.url,
              if (a.width != null) 'w': a.width,
              if (a.height != null) 'h': a.height,
              if (a.blurhash != null) 'b': a.blurhash,
              if (a.filename != null) 'n': a.filename,
            },
        ],
    });
  }

  /// Inverse of [_encodeMessageEnvelope]. Legacy/plain payloads decode to the
  /// raw text with no references / markers / attachments.
  ({
    String content,
    List<String> eTagRefs,
    String? rootEventId,
    String? replyToEventId,
    String? quoteEventId,
    List<MediaAttachment> attachments,
  }) _decodeMessageEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map &&
          decoded['c'] is String &&
          decoded['e'] is List) {
        final rawImeta = decoded['i'];
        final attachments = <MediaAttachment>[];
        if (rawImeta is List) {
          for (final m in rawImeta) {
            if (m is! Map) continue;
            final sha = m['x'];
            final mime = m['m'];
            if (sha is! String || mime is! String) continue;
            attachments.add(MediaAttachment()
              ..sha256 = sha
              ..mime = mime
              ..sizeBytes = (m['s'] as int?) ?? 0
              ..url = m['u'] as String?
              ..width = m['w'] as int?
              ..height = m['h'] as int?
              ..blurhash = m['b'] as String?
              ..filename = m['n'] as String?);
          }
        }
        return (
          content: decoded['c'] as String,
          eTagRefs: (decoded['e'] as List).cast<String>(),
          rootEventId: decoded['r'] as String?,
          replyToEventId: decoded['y'] as String?,
          quoteEventId: decoded['q'] as String?,
          attachments: attachments,
        );
      }
    } catch (_) {
      // Not an envelope — fall through to plain text.
    }
    return (
      content: raw,
      eTagRefs: const [],
      rootEventId: null,
      replyToEventId: null,
      quoteEventId: null,
      attachments: const [],
    );
  }

  /// Builds an [EventQueueModel] from a fully-signed Marmot [Event]. The
  /// `["h", groupId]` tag is extracted into [EventQueueModel.hTag] so the
  /// queue's serializer can reproduce the tag at send time.
  EventQueueModel _buildQueueEntry(Event event) {
    String? hTag;
    for (final t in event.tags) {
      if (t.isEmpty) continue;
      if (t[0] == 'h' && t.length > 1) {
        hTag = t[1];
        break;
      }
    }
    return EventQueueModel()
      ..eventId = event.id
      ..kind = event.kind
      ..content = event.content
      ..authorPubkey = event.pubkey
      ..sig = event.sig
      ..eTagRefs = []
      ..pTagRefs = []
      ..tTags = []
      ..hTag = hTag
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
  ///
  /// [quoteEventId] is a NIP-18 `q` tag carried inside the encrypted envelope.
  Future<void> sendChannelMessage({
    required String groupId,
    required String content,
    required String authorPubkey,
    required String privkeyHex,
    List<String> mentionRefs = const [],
    String? rootEventId,
    String? replyToEventId,
    String? quoteEventId,
    List<MediaBlobEntity> attachments = const [],
  }) async {
    final channel = await _findChannel(groupId);
    if (channel == null) {
      throw Exception('Private channel not found locally for groupId: $groupId');
    }
    if (channel.mlsGroupId.isEmpty) {
      throw Exception('MLS group is not initialized for groupId: $groupId');
    }

    final imeta = [
      for (final b in attachments)
        MediaAttachment()
          ..sha256 = b.sha256
          ..mime = b.mime
          ..sizeBytes = b.sizeBytes
          ..url = b.serverUrls.isNotEmpty ? b.serverUrls.first : null
          ..width = b.dim?.width
          ..height = b.dim?.height
          ..blurhash = b.blurhash
          ..filename = b.filename,
    ];

    final encryptedPayload = await _mlsService.encryptMessage(
      groupId: channel.mlsGroupId,
      content: _encodeMessageEnvelope(
        content,
        mentionRefs,
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        quoteEventId: quoteEventId,
        attachments: imeta,
      ),
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

    final localMessage = NoteModel(
      eventId: event.id,
      sig: '',
      authorPubkey: authorPubkey,
      content: content,
      kind: kPrivateChannelKind,
      groupId: groupId,
      type: imeta.any((a) => a.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text,
      eTagRefs: mentionRefs,
      rootEventId: rootEventId,
      replyToEventId: replyToEventId,
      pTagRefs: const [],
      tTags: const [],
      created: now,
      quoteEventId: quoteEventId,
      attachments: imeta,
    );

    await _isar.writeTxn(() async {
      await _isar.noteModels.put(localMessage);
      final parents = replyEdgeParentIds(
        replyToEventId: null,
        rootEventId: null,
        eTagRefs: localMessage.eTagRefs,
      );
      await _relations.addEdgesInTxn(
        parents: parents,
        childId: localMessage.eventId,
      );
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

    // A member may tap "request to join" several times, producing multiple
    // join-request rows that all share one persistent MLS signature key.
    // Resolve the requester so every one of their pending rows is cleared on
    // approval — otherwise a leftover row could be approved again and OpenMLS
    // would reject the duplicate signature key.
    final senderPubkey =
        await _senderForKeyPackage(groupId, userKeyPackageB64);

    try {
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
        await _deletePendingRequestsInTxn(
          groupId,
          userKeyPackageB64,
          senderPubkey,
        );
      });
    } catch (e) {
      // The member's signature key is already in the group — they were added by
      // a previous commit. Treat as success and drop the stale request(s)
      // instead of surfacing "Duplicate signature key" to the admin.
      if (_isAlreadyMemberError(e)) {
        await _isar.writeTxn(() async {
          await _deletePendingRequestsInTxn(
            groupId,
            userKeyPackageB64,
            senderPubkey,
          );
        });
        return;
      }
      rethrow;
    }
  }

  /// The pubkey that submitted [keyPackageB64] for [groupId], if a pending
  /// request row still exists for it.
  Future<String?> _senderForKeyPackage(
    String groupId,
    String keyPackageB64,
  ) async {
    final requests = await _isar.privateChannelJoinRequestModels
        .where()
        .groupIdEqualTo(groupId)
        .findAll();
    return requests
        .where((request) => request.keyPackageB64 == keyPackageB64)
        .map((request) => request.senderPubkey)
        .firstOrNull;
  }

  /// Deletes every pending join request for [groupId] that either matches the
  /// approved [keyPackageB64] or was submitted by [senderPubkey] (a member may
  /// have several outstanding requests sharing one signature key).
  Future<void> _deletePendingRequestsInTxn(
    String groupId,
    String keyPackageB64,
    String? senderPubkey,
  ) async {
    final requests = await _isar.privateChannelJoinRequestModels
        .where()
        .groupIdEqualTo(groupId)
        .findAll();
    final ids = requests
        .where((request) =>
            request.keyPackageB64 == keyPackageB64 ||
            (senderPubkey != null && request.senderPubkey == senderPubkey))
        .map((request) => request.id)
        .toList();
    if (ids.isNotEmpty) {
      await _isar.privateChannelJoinRequestModels.deleteAll(ids);
    }
  }

  bool _isAlreadyMemberError(Object error) {
    return error.toString().toLowerCase().contains('duplicate signature key');
  }
}
