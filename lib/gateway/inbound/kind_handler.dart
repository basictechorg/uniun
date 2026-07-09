import 'package:isar_community/isar.dart';
import 'package:uniun/gateway/inbound/verified_nostr_event.dart';

/// Handles inbound Nostr events of one (or a few) kind(s).
///
/// One implementation per kind/group. The [InboundBus] picks the first handler
/// whose [kinds] set contains the event's `kind` field.
abstract class KindHandler {
  /// Set of Nostr `kind` integers this handler processes.
  Set<int> get kinds;

  /// Parse and persist [event]. Must be idempotent — duplicate
  /// deliveries from concurrent relays are expected.
  Future<void> handle(VerifiedNostrEvent event, Isar isar);
}
