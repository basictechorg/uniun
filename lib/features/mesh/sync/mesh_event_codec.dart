import 'dart:convert';

import 'package:nip44/nip44.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/core/notes/note_kinds.dart' show MeshEventKinds;

export 'package:uniun/core/notes/note_kinds.dart' show MeshEventKinds;

/// State field carried inside every mesh-record body. Undo (unsave / unfollow
/// / unblock / delete Manas / delete Gana / un-hide) publishes a NEW event
/// with the same `(kind, d)`, a newer `created_at`, and `state = removed`.
/// Receiver dispatch sets a `removedAt` timestamp on the corresponding Isar
/// row but keeps the row so future negentropy passes still surface the
/// tombstone. See plan §5a.
enum MeshRecordState {
  active,
  removed;

  String get wire => name;

  static MeshRecordState parse(Object? value) => switch (value) {
    'removed' => MeshRecordState.removed,
    _ => MeshRecordState.active,
  };
}

/// One decoded mesh event, ready for the per-kind Isar upsert to consume.
class MeshEventRecord {
  const MeshEventRecord({
    required this.event,
    required this.kind,
    required this.dTag,
    required this.createdAt,
    required this.state,
    required this.content,
  });

  /// Original signed event JSON (as a Map). Consumers can re-serialize with
  /// `jsonEncode` if they need to stash it back into `signedNostrEvent`.
  final Map<String, dynamic> event;

  /// The event's `kind` — one of [MeshEventKinds].
  final int kind;

  /// The event's `d` tag value (identifies the addressable slot).
  final String dTag;

  /// Unix seconds — the LWW ordering key per `(kind, d)`.
  final int createdAt;

  /// Active-vs-removed toggle. See [MeshRecordState].
  final MeshRecordState state;

  /// Decrypted body per plan §5. Kind-specific shape.
  final Map<String, dynamic> content;
}

/// Encodes / decodes signed, NIP-44-self-encrypted Nostr events that carry
/// mesh-only Uniun rows (saves, follows, blocks, Manases, Ganas, …).
///
/// Wire recipe per plan §3:
///
/// 1. Serialize the cleartext body ([signRecord] takes it as a Map).
/// 2. NIP-44 v2 encrypt with `sharedSecret(myPriv, myPub)` — both mesh peers
///    hold the same privkey, so both derive the same shared secret and can
///    decrypt.
/// 3. Assemble `{kind, pubkey=myPub, created_at, tags=[["d", dTag]], content=cipher}`
///    and Schnorr-sign it via `nostr_core_dart` — same code path the relay
///    outbound queue uses, so the resulting JSON is byte-for-byte a normal
///    Nostr event, just with a Uniun-private kind.
///
/// On receive [openRecord] verifies id, sig, and pubkey against the active
/// identity before decrypting; any failure raises a [MeshCodecException] and
/// the caller drops the row.
class MeshEventCodec {
  const MeshEventCodec({required this.privkeyHex, required this.pubkeyHex});

  /// Active identity's 32-byte hex private key.
  final String privkeyHex;

  /// Active identity's 32-byte hex public key (must equal `Keychain(privkey).public`).
  final String pubkeyHex;

  /// Builds a signed + NIP-44-encrypted mesh event ready to be stashed in
  /// `signedNostrEvent` and shipped to a peer. `content` is the plaintext
  /// body per plan §5; it MUST include a `state` field (see [MeshRecordState]).
  Future<String> signRecord({
    required int kind,
    required String dTag,
    required Map<String, dynamic> content,
    int? createdAtSec,
  }) async {
    if (kind < 30000 || kind > 39999) {
      throw ArgumentError.value(
        kind,
        'kind',
        'MeshEventCodec is only intended for addressable custom kinds (30000-39999).',
      );
    }
    final plaintext = jsonEncode(content);
    final ciphertext = await Nip44.encryptMessage(
      plaintext,
      privkeyHex,
      pubkeyHex, // self-encrypt: recipient is our own pubkey
    );
    final event = Event.from(
      kind: kind,
      tags: [
        ['d', dTag],
      ],
      content: ciphertext,
      privkey: privkeyHex,
      createdAt: createdAtSec ?? currentUnixTimestampSeconds(),
    );
    return jsonEncode(event.toJson());
  }

  /// Verifies + decrypts one mesh event. Throws [MeshCodecException] on any
  /// integrity failure (bad JSON, id/hash mismatch, bad Schnorr signature,
  /// wrong pubkey, no `d` tag, plaintext body malformed / not JSON, unknown
  /// state). The caller MUST log-and-drop on exception rather than propagate.
  Future<MeshEventRecord> openRecord(String signedJson) async {
    late final Map<String, dynamic> raw;
    try {
      final decoded = jsonDecode(signedJson);
      if (decoded is! Map<String, dynamic>) {
        throw const MeshCodecException('event JSON is not an object');
      }
      raw = decoded;
    } catch (e) {
      if (e is MeshCodecException) rethrow;
      throw MeshCodecException('invalid event JSON: $e');
    }

    late final Event event;
    try {
      // verify:false — nostr_core_dart's built-in verify uses `assert` (stripped
      // in release). We check `isValid()` explicitly below.
      event = Event.fromJson(raw, verify: false);
    } catch (e) {
      throw MeshCodecException('event decode failed: $e');
    }

    if (!event.isValid()) {
      throw const MeshCodecException('event id/signature invalid');
    }
    if (event.pubkey.toLowerCase() != pubkeyHex.toLowerCase()) {
      throw MeshCodecException(
        'wrong pubkey: got ${event.pubkey} expected $pubkeyHex',
      );
    }

    String? dTag;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'd' && tag.length >= 2) {
        dTag = tag[1];
        break;
      }
    }
    if (dTag == null || dTag.isEmpty) {
      throw const MeshCodecException('missing d tag');
    }

    late final String plaintext;
    try {
      plaintext = await Nip44.decryptMessage(
        event.content,
        privkeyHex,
        pubkeyHex, // self: sender is our own pubkey
      );
    } catch (e) {
      throw MeshCodecException('NIP-44 decrypt failed: $e');
    }

    late final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map<String, dynamic>) {
        throw const MeshCodecException('body is not a JSON object');
      }
      body = decoded;
    } catch (e) {
      if (e is MeshCodecException) rethrow;
      throw MeshCodecException('body JSON invalid: $e');
    }

    return MeshEventRecord(
      event: raw,
      kind: event.kind,
      dTag: dTag,
      createdAt: event.createdAt,
      state: MeshRecordState.parse(body['state']),
      content: body,
    );
  }
}

/// Thrown by [MeshEventCodec.openRecord] on any integrity / decrypt failure.
/// Callers should log and drop the offending event.
class MeshCodecException implements Exception {
  const MeshCodecException(this.reason);
  final String reason;

  @override
  String toString() => 'MeshCodecException($reason)';
}
