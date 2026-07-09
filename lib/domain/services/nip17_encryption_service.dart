import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:isar_community/isar.dart';
import 'package:nip44/nip44.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/core/notes/reply_edge.dart';
import 'package:uniun/features/mesh/sync/bodies/dm_conversation_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/gateway/inbound/missing_profile_tracker.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/dm/encrypted_dm_model.dart';
import 'package:uniun/data/models/notes/media_attachment.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/data/models/notes/unread_note_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/domain/repositories/note_relation_repository.dart';
// user_key_model not needed — privkey is injected via constructor
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/notes/imeta_parser.dart';

class Nip17EncryptionService {
  final Isar _isar;
  final NoteRelationRepository _relations;

  /// The active user's private key as raw 32-byte hex.
  /// Passed in from the gateway isolate bootstrap (read from FlutterSecureStorage
  /// in the main isolate before spawn, since SecureStorage is unavailable in isolates).
  final String? _privkeyHex;

  /// Lazily-built mesh codec bound to the active identity, used to sign the
  /// auto-created DmConversation row when a first-time DM arrives. Nulled
  /// out when there is no active user (that also nulls out DM decryption
  /// itself). Cached because DM inbound is bursty.
  MeshEventCodec? _meshCodec;

  Nip17EncryptionService(
    this._isar,
    this._relations, {
    String? privkeyHex,
  }) : _privkeyHex = privkeyHex;

  MeshEventCodec? _codec() {
    if (_meshCodec != null) return _meshCodec;
    if (_privkeyHex == null || _privkeyHex.isEmpty) return null;
    final pubkey = Keychain(_privkeyHex).public;
    _meshCodec =
        MeshEventCodec(privkeyHex: _privkeyHex, pubkeyHex: pubkey);
    return _meshCodec;
  }

  /// Start watching the Isar collection for new incoming encrypted DMs
  /// (e.g., from the gateway's WebSocketService)
  void start() {
    _isar.encryptedDmModels.watchLazy().listen((_) async {
      await processInboundQueue();
    });
    // initial process
    processInboundQueue();
  }

  Future<void> processInboundQueue() async {
    final pending = await _isar.encryptedDmModels.where().findAll();
    if (pending.isEmpty) return;

    final myPrivkey = _privkeyHex;
    if (myPrivkey == null) return; // No key available yet

    for (final dm in pending) {
      try {
        // NIP-17 Receive Flow:

        // 1. The dm.content is Nip44 encrypted Kind 13 Seal, sent by dm.authorPubkey (a random pubkey)
        final sealJsonStr = await Nip44.decryptMessage(
          dm.content,
          myPrivkey,
          dm.authorPubkey,
        );
        final sealEvent = jsonDecode(sealJsonStr) as Map<String, dynamic>;

        if (sealEvent['kind'] != 13) {
          throw Exception('Invalid inner seal kind: ${sealEvent['kind']}');
        }

        // 2. The seal's content is Nip44 encrypted Kind 14 Chat Payload, sent by the seal's pubkey
        final sealSenderPubkey = sealEvent['pubkey'] as String;
        final sealContent = sealEvent['content'] as String;

        final chatJsonStr = await Nip44.decryptMessage(
          sealContent,
          myPrivkey,
          sealSenderPubkey,
        );
        final chatEvent = jsonDecode(chatJsonStr) as Map<String, dynamic>;

        final chatKind = chatEvent['kind'] as int;
        if (chatKind != 14 && chatKind != 15 && chatKind != 7) {
          throw Exception('Invalid chat msg kind: $chatKind');
        }

        // 3. Prevent impersonation
        if (chatEvent['pubkey'] != sealSenderPubkey) {
          throw Exception('Impersonation attack blocked. Pubkey mismatch.');
        }

        // Prepare the recovered json to be fully compatible with DmMessageModel.fromEvent
        // Wait, Event.fromJson crashes natively if 'sig' is absent in NIP-14 unsigned payloads!
        // We will manually extract exactly what we need directly from the Map!

        // Ensure subject falls back to null if empty
        String? subject;
        final pTagRefs = <String>[];
        final eTagRefs = <String>[];
        String? rootTo;
        String? replyTo;
        String? embeddedNoteJson;

        final tagsList = chatEvent['tags'] as List<dynamic>? ?? [];
        for (final tagObj in tagsList) {
          if (tagObj is! List<dynamic> || tagObj.isEmpty) continue;
          if (tagObj[0] == 'p' && tagObj.length >= 2) pTagRefs.add(tagObj[1] as String);
          if (tagObj[0] == 'e' && tagObj.length >= 2) {
            eTagRefs.add(tagObj[1] as String);
            // Marker (index 3): "mention" is a reference only, "root" marks the
            // thread root; otherwise it's the direct parent.
            final marker = tagObj.length >= 4 ? tagObj[3] : null;
            if (marker == 'root') {
              rootTo ??= tagObj[1] as String;
            } else if (marker != 'mention') {
              replyTo ??= tagObj[1] as String;
            }
          }
          if (tagObj[0] == EmbeddedNoteCodec.tagName && tagObj.length >= 2) {
            // Embed-by-value share — verify the snapshot once, here at the edge.
            embeddedNoteJson =
                EmbeddedNoteCodec.verifyAndSanitize(tagObj[1] as String);
          }
          if (tagObj[0] == 'subject' && tagObj.length >= 2) subject = tagObj[1] as String;
        }

        final otherPubkey = sealSenderPubkey;

        // Materialize (or reactivate) the DmConversation row BEFORE the inner
        // note-write txn — signing the mesh event is async (NIP-44 encrypt),
        // so it can't live inside `writeTxn`. The row's unique+replace index
        // on `otherPubkey` makes this safe against a concurrent second DM
        // from the same peer.
        var conv = await _isar.dmConversationModels
            .where()
            .otherPubkeyEqualTo(otherPubkey)
            .findFirst();
        if (conv == null || conv.removedAt != null) {
          conv = (conv ?? DmConversationModel())
            ..otherPubkey = otherPubkey
            ..removedAt = null;
          final codec = _codec();
          if (codec != null) {
            try {
              conv.signedNostrEvent = await codec.signRecord(
                kind: MeshEventKinds.dmConversation,
                dTag: otherPubkey,
                content: DmConversationBody.forActive(conv),
              );
            } catch (_) {
              // Non-fatal — the row still lands in Isar; the mesh migration
              // pass will backfill `signedNostrEvent` on next launch.
            }
          }
          await _isar.writeTxn(() async {
            await _isar.dmConversationModels.put(conv!);
          });
        }

        final parsedEventId = chatEvent['id'] as String? ?? '';
        final contentVal = chatEvent['content'] as String? ?? '';
        final type = _inferTypeFromUrl(contentVal); // simple fallback

        // NIP-92 imeta — embedded inside the encrypted rumor by sendDm.
        // Parser is the same one Kind 1/42 handlers use; it just walks
        // the tag list looking for `imeta` entries.
        final attachments = ImetaParser.parseAsAttachments(chatEvent);

        final dmModel = NoteModel(
          eventId: parsedEventId,
          sig: '', // Has no valid NIP-01 sig because it's deniable.
          authorPubkey: chatEvent['pubkey'] as String? ?? '',
          conversationId: conv.id,
          pTagRefs: pTagRefs,
          rootEventId: rootTo,
          replyToEventId: replyTo,
          eTagRefs: eTagRefs,
          content: contentVal,
          subject: subject,
          kind: chatEvent['kind'] as int? ?? kDmTextKind,
          type: chatKind == 15 ? type : NoteType.text,
          tTags: const [],
          created: DateTime.fromMillisecondsSinceEpoch(
            (chatEvent['created_at'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000)) * 1000,
          ),
          embeddedNoteJson: embeddedNoteJson,
          attachments: attachments,
        );

        await _isar.writeTxn(() async {
          // Duplicate collision defense
          final existingMsg = await _isar.noteModels
              .where()
              .eventIdEqualTo(parsedEventId)
              .findFirst();

          if (existingMsg != null) {
              // Message exists, just discard the inbound encrypted envelope
              await _isar.encryptedDmModels.delete(dm.id);
              return;
          }

          await _isar.noteModels.put(dmModel);
          // Unread row for DMs from the other party (own copies are pre-seen).
          final pk = _privkeyHex;
          final ownPubkey = pk != null ? Keychain(pk).public : null;
          if (dmModel.authorPubkey != ownPubkey) {
            await putUnreadRowInTxn(_isar, dmModel);
          }
          // Record reference edges via the shared repo. The unique
          // (parentId, childId) index keeps re-delivery idempotent.
          final parents = replyEdgeParentIds(
            replyToEventId: replyTo,
            rootEventId: null,
            eTagRefs: replyTo != null ? [replyTo] : const [],
          );
          await _relations.addEdgesInTxn(
            parents: parents,
            childId: parsedEventId,
          );
          // Consume encrypted wrapper from queue
          await _isar.encryptedDmModels.delete(dm.id);
        });
        // Flag the seal-sender for profile fetch if we don't have one yet.
        await MissingProfileTracker(_isar).trackPubkey(sealSenderPubkey);
      } catch (e, st) {
        print("Failed to decrypt GiftWrap ${dm.eventId}: $e\n$st");
        // Always delete on failure so we don't indefinitely panic on bad cryptography
        await _isar.writeTxn(() async {
          await _isar.encryptedDmModels.delete(dm.id);
        });
      }
    }
  }

  /// Sends a direct message to a receiver, wrapping it according to NIP-17.
  Future<void> sendDm(NoteModel unsignedModel, {required String receiverPubkey}) async {
    final myPrivkey = _privkeyHex;
    if (myPrivkey == null) throw Exception('No private key available.');
    
    print('DEBUG sendDm: Checking myPrivkey len=${myPrivkey.length}, receiverPubkey len=${receiverPubkey.length}');

    int step = 0;
    try {
      final myPubkey = Keychain(myPrivkey).public;

      // 1. Immediately store unencrypted Dm in local DB + reference edges.
      await _isar.writeTxn(() async {
        await _isar.noteModels.put(unsignedModel);
        final parents = replyEdgeParentIds(
          replyToEventId: unsignedModel.replyToEventId,
          rootEventId: null,
          eTagRefs: unsignedModel.replyToEventId != null
              ? [unsignedModel.replyToEventId!]
              : const [],
        );
        await _relations.addEdgesInTxn(
          parents: parents,
          childId: unsignedModel.eventId,
        );
      });

      final now = DateTime.now();
      final currentSec = now.millisecondsSinceEpoch ~/ 1000;

      // Mention refs = all e-tag ids except the NIP-10 root/reply markers.
      final mentionRefs = unsignedModel.eTagRefs
          .where((id) =>
              id != unsignedModel.replyToEventId &&
              id != unsignedModel.rootEventId)
          .toList();

      // Build the NIP-14 unsigned payload. When the model carries an
      // [embeddedNoteJson] (a share/quote), emit the embed-by-value snapshot
      // tag inside the encrypted rumor so the receiver renders the embed.
      final chatPayload = {
        'pubkey': myPubkey,
        'created_at': currentSec,
        'kind': unsignedModel.kind,
        'tags': [
          ['p', receiverPubkey],
          if (unsignedModel.rootEventId != null)
            ['e', unsignedModel.rootEventId, '', 'root'],
          if (unsignedModel.replyToEventId != null)
            ['e', unsignedModel.replyToEventId, '', 'reply'],
          for (final id in mentionRefs) ['e', id, '', 'mention'],
          if (unsignedModel.embeddedNoteJson != null)
            EmbeddedNoteCodec.tag(unsignedModel.embeddedNoteJson!),
          // NIP-92 imeta — one tag per attachment. The relay never sees this
          // (it's inside the encrypted seal); the receiver decrypts, walks
          // the tags, and rebuilds NoteModel.attachments.
          for (final a in unsignedModel.attachments) _imetaTag(a),
        ],
        'content': unsignedModel.content,
      };
      final serializedChat = [
        0,
        chatPayload['pubkey'],
        chatPayload['created_at'],
        chatPayload['kind'],
        chatPayload['tags'],
        chatPayload['content']
      ];
      // Hash gives the correct nostr id
      chatPayload['id'] = sha256.convert(utf8.encode(jsonEncode(serializedChat))).toString(); 
      
      // 2. Wrap in Kind 13 Seal (Signed by Me)
      step = 1;
      final strChat = jsonEncode(chatPayload);
      final encChat = await Nip44.encryptMessage(strChat, myPrivkey, receiverPubkey);
      
      step = 2;
      final sealEvent = Event.from(
        privkey: myPrivkey,
        kind: 13, 
        tags: const [],
        content: encChat,
        createdAt: currentSec,
      );

      // 3. Wrap in Kind 1059 Gift Wrap (Signed by a Random throw-away key)
      step = 3;
      final randomPrivkey = Keychain.generate().private;
      
      step = 4;
      final strSeal = jsonEncode(sealEvent.toJson());
      final encSeal = await Nip44.encryptMessage(strSeal, randomPrivkey, receiverPubkey);

      step = 5;
      final giftWrapEvent = Event.from(
        privkey: randomPrivkey,
        kind: 1059,
        tags: [
          ['p', receiverPubkey]
        ],
        content: encSeal,
        createdAt: currentSec,
      );

      // 4. Push to EventQueueModel so CentralRelayManager targets it across networks
      final eventQueueModel = EventQueueModel()
        ..eventId = giftWrapEvent.id
        ..authorPubkey = giftWrapEvent.pubkey
        ..sig = giftWrapEvent.sig
        ..kind = 1059
        ..content = giftWrapEvent.content
        ..eTagRefs = const []
        ..pTagRefs = [receiverPubkey]
        ..tTags = const []
        ..rootEventId = null
        ..replyToEventId = null
        ..created = now
        ..sentCount = 0
        ..enqueuedAt = now;

      await _isar.writeTxn(() async {
        await _isar.eventQueueModels.put(eventQueueModel);
      });
      print('DEBUG sendDm: Success!');
    } catch (e) {
       print('DEBUG sendDm: CRASH at step $step. Error: $e');
       rethrow;
    }
  }

  /// Builds one NIP-92 `imeta` tag from an embedded [MediaAttachment].
  /// Shape matches what the relay-facing publishers emit so encrypted and
  /// public surfaces stay byte-identical.
  static List<String> _imetaTag(MediaAttachment a) {
    return [
      'imeta',
      if (a.url != null) 'url ${a.url}',
      'm ${a.mime}',
      'x ${a.sha256}',
      if (a.sizeBytes > 0) 'size ${a.sizeBytes}',
      if (a.width != null && a.height != null) 'dim ${a.width}x${a.height}',
      if (a.blurhash != null) 'blurhash ${a.blurhash}',
      if (a.filename != null && a.filename!.isNotEmpty) 'name ${a.filename}',
    ];
  }

  NoteType _inferTypeFromUrl(String content) {
    if (content.startsWith('http')) {
      final lower = content.toLowerCase();
      if (lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.png') ||
          lower.contains('.gif') ||
          lower.contains('.webp')) {
        return NoteType.image;
      }
      return NoteType.link;
    }
    return NoteType.text;
  }
}
