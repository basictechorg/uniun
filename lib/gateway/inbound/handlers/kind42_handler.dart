import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_message_model.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';
import 'package:uniun/gateway/inbound/kind_handler.dart';

/// Kind 42 — NIP-28 channel message.
///
/// Tag walk picks out root/reply e-tags via NIP-10 markers. Falls back to
/// positional first/last when markers are absent (legacy NIP-10).
class Kind42Handler implements KindHandler {
  @override
  Set<int> get kinds => const {42};

  @override
  Future<void> handle(Map<String, dynamic> event, Isar isar) async {
    final eventId = event['id'] as String?;
    final pubkey = event['pubkey'] as String?;
    final sig = event['sig'] as String?;
    final content = event['content'] as String?;
    final createdAtSec = event['created_at'] as int?;

    if (eventId == null ||
        pubkey == null ||
        sig == null ||
        content == null ||
        createdAtSec == null) {
      return;
    }

    final tags = event['tags'] as List<dynamic>? ?? [];
    String? channelId;
    String? replyEventId;
    final eTagRefs = <String>[];

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

    if (channelId == null && eTagRefs.isNotEmpty) channelId = eTagRefs.first;
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
      ..created = EventParser.dateTimeFromSec(createdAtSec);

    try {
      await isar.writeTxn(() async {
        final existing = await isar.channelMessageModels
            .where()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (existing != null) return;
        await isar.channelMessageModels.put(model);
      });
    } catch (_) {
      return;
    }
  }
}
