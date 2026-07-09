import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'package:uniun/gateway/inbound/handlers/kind0_profile_handler.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

import '../sync_scope.dart';

/// Reconciles cached public Nostr Kind 0 profile events via NIP-77 negentropy.
///
/// # Wire format
///
/// Unlike the 3050x mesh kinds, these events are relay-authored public Nostr
/// events. They are NOT NIP-44 encrypted — encrypting them would break relay
/// compatibility and pointlessly hide a value the relay already publishes. The
/// scope forwards the raw signed JSON verbatim so mesh peers verify by the
/// standard `id = SHA256(canonical) && Schnorr sig valid && author = pubkey`
/// rule.
///
/// # Storage
///
/// Kind 0 is served from [ProfileModel.rawEventJson]. Kind 3 contact-list
/// state syncs one followed user at a time through `FollowedUserSyncScope`.
///
/// # LWW
///
/// Kind 0 is addressable-by-pubkey. The profile handler enforces LWW by
/// `created_at`, so an out-of-order or stale event received via the mesh is a
/// no-op on the derived profile row.
///
/// # Author policy
///
/// - Kind 0: any author. The user's local profile store carries other
///   people's profiles so their names / avatars render in the UI.
/// Anything else (bad JSON, bad sig, wrong kind, foreign Kind 3) is silently
/// dropped. No back-channel to the peer.
class PublicEventSyncScope implements NegentropySyncScope {
  PublicEventSyncScope(
    this._isar, {
    this.activePubkeyHex,
    KindHandler? kind0Handler,
  }) : _kind0 = kind0Handler ?? Kind0ProfileHandler();

  final Isar _isar;
  final KindHandler _kind0;

  /// The active identity's hex pubkey.
  final String? activePubkeyHex;

  @override
  String get name => 'publicEvent';

  @override
  Future<Map<String, int>> localIndex() async {
    final out = <String, int>{};
    final profiles = await _isar.profileModels.where().findAll();
    for (final profile in profiles) {
      final raw = profile.rawEventJson;
      if (raw == null) continue;
      final event = _decodeValidEvent(raw);
      if (event == null || event.kind != 0) continue;
      out[event.id] = event.createdAt;
    }
    return out;
  }

  @override
  Future<String?> signedEvent(String eventId) async {
    final profiles = await _isar.profileModels.where().findAll();
    for (final profile in profiles) {
      final raw = profile.rawEventJson;
      if (raw == null) continue;
      final event = _decodeValidEvent(raw);
      if (event != null && event.kind == 0 && event.id == eventId) {
        return raw;
      }
    }

    return null;
  }

  @override
  Future<void> upsertSigned(String signedEventJson) async {
    late final Map<String, dynamic> raw;
    late final VerifiedNostrEvent event;
    try {
      final decoded = jsonDecode(signedEventJson);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('MESH/SYNC: publicEvent JSON not an object');
        return;
      }
      raw = decoded;
      final verified = const NostrEventVerifier().verify(raw);
      if (verified == null) {
        debugPrint('MESH/SYNC: publicEvent id/sig invalid');
        return;
      }
      event = verified;
    } catch (e) {
      debugPrint('MESH/SYNC: publicEvent decode failed: $e');
      return;
    }

    switch (event.kind) {
      case 0:
        await _kind0.handle(event, _isar);
        break;
      default:
        // Not a kind this scope owns. Silently drop.
        return;
    }
  }

  Event? _decodeValidEvent(String signedEventJson) {
    try {
      final decoded = jsonDecode(signedEventJson);
      if (decoded is! Map<String, dynamic>) return null;
      final event = Event.fromJson(decoded, verify: false);
      return event.isValid() ? event : null;
    } catch (_) {
      return null;
    }
  }
}
