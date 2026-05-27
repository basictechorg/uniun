import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

/// NIP-17 direct messages (gift-wrapped kind 1059).
///
/// Reads the first p-tag from [EventQueueModel.pTagRefs] as the recipient
/// pubkey, looks up the [DMConversationModel] for that peer, and uses its
/// stored relays. Falls back to all main relays when missing.
class DmRoutingStrategy implements RoutingStrategy {
  @override
  bool matches(EventQueueModel event) => event.kind == 1059;

  @override
  Future<List<String>?> resolveTargets(
    EventQueueModel event,
    Isar isar,
  ) async {
    if (event.pTagRefs.isEmpty) return null;
    final receiverPubkey = event.pTagRefs.first;

    final conversation = await isar.dmConversationModels
        .where()
        .otherPubkeyEqualTo(receiverPubkey)
        .findFirst();
    if (conversation != null && conversation.relays.isNotEmpty) {
      return conversation.relays;
    }
    return null;
  }
}
