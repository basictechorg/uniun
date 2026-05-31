import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:isar_community/isar.dart';
import 'package:nip44/nip44.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/dm/dm_message_model.dart';
import 'package:uniun/data/models/dm/encrypted_dm_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
// user_key_model not needed — privkey is injected via constructor
import 'package:uniun/core/enum/note_type.dart';

class Nip17EncryptionService {
  final Isar _isar;

  /// The active user's private key as raw 32-byte hex.
  /// Passed in from the gateway isolate bootstrap (read from FlutterSecureStorage
  /// in the main isolate before spawn, since SecureStorage is unavailable in isolates).
  final String? _privkeyHex;

  Nip17EncryptionService(this._isar, {String? privkeyHex})
    : _privkeyHex = privkeyHex;

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
          if (tagObj[0] == 'subject' && tagObj.length >= 2) subject = tagObj[1] as String;
        }

        final otherPubkey = sealSenderPubkey;

        await _isar.writeTxn(() async {
          // Lookup or create a Conversation wrapper for this other pubkey
          var conv = await _isar.dmConversationModels
              .where()
              .otherPubkeyEqualTo(otherPubkey)
              .findFirst();

          if (conv == null) {
            conv = DmConversationModel()..otherPubkey = otherPubkey;
            await _isar.dmConversationModels.put(conv);
          }

          final parsedEventId = chatEvent['id'] as String? ?? '';

          // Duplicate collision defense
          final existingMsg = await _isar.dmMessageModels
              .where()
              .eventIdEqualTo(parsedEventId)
              .findFirst();
              
          if (existingMsg != null) {
              // Message exists, just discard the inbound encrypted envelope
              await _isar.encryptedDmModels.delete(dm.id);
              return;
          }

          final contentVal = chatEvent['content'] as String? ?? '';
          final type = _inferTypeFromUrl(contentVal); // simple fallback

          final dmModel = DmMessageModel(
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
            kind: chatEvent['kind'] as int? ?? 14,
            type: chatKind == 15 ? type : NoteType.text,
            created: DateTime.fromMillisecondsSinceEpoch(
              (chatEvent['created_at'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000)) * 1000,
            ),
            isSeen: false,
          );

          await _isar.dmMessageModels.put(dmModel);
          // Consume encrypted wrapper from queue
          await _isar.encryptedDmModels.delete(dm.id);
        });
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
  Future<void> sendDm(DmMessageModel unsignedModel, {required String receiverPubkey}) async {
    final myPrivkey = _privkeyHex;
    if (myPrivkey == null) throw Exception('No private key available.');
    
    print('DEBUG sendDm: Checking myPrivkey len=${myPrivkey.length}, receiverPubkey len=${receiverPubkey.length}');

    int step = 0;
    try {
      final myPubkey = Keychain(myPrivkey).public;

      // 1. Immediately store unencrypted Dm in local DB
      await _isar.writeTxn(() async {
        await _isar.dmMessageModels.put(unsignedModel);
      });

      final now = DateTime.now();
      final currentSec = now.millisecondsSinceEpoch ~/ 1000;

      // Mention refs = all e-tag ids except the NIP-10 root/reply markers.
      final mentionRefs = unsignedModel.eTagRefs
          .where((id) =>
              id != unsignedModel.replyToEventId &&
              id != unsignedModel.rootEventId)
          .toList();

      // Build the NIP-14 unsigned payload
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
    } catch (e, stack) {
       print('DEBUG sendDm: CRASH at step $step. Error: $e');
       rethrow;
    }
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
