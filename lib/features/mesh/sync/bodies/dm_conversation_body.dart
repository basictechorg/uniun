import 'package:uniun/data/models/dm/dm_conversation_model.dart';

import '../mesh_event_codec.dart';

/// Cleartext body shape for the Kind-30503 DmConversation mesh event
/// (plan §5).
///
/// The `d` tag is the counterparty pubkey (which is also the row's natural
/// key). Save-conversation/delete-conversation both address the same
/// addressable slot — LWW on `created_at` picks the winner.
///
/// `relays` is carried so a fresh device can reach the counterparty over the
/// same relays the origin was using; empty list means "use the app's default
/// relay set".
///
/// **Deliberately NOT synced:** `lastReadEventId` and any other unread-badge
/// state. Cross-device read receipts are out of scope — you don't want your
/// unread count on your phone to jump because you scrolled past on your
/// laptop.
class DmConversationBody {
  const DmConversationBody._();

  static Map<String, dynamic> forActive(DmConversationModel m) => _base(
        m,
        state: MeshRecordState.active,
      );

  /// Removed variant — carries the same shape so the tombstone alone can
  /// re-materialize the row on a peer that never saw the "active" event.
  static Map<String, dynamic> forRemoved(DmConversationModel m) => _base(
        m,
        state: MeshRecordState.removed,
      );

  static Map<String, dynamic> _base(
    DmConversationModel m, {
    required MeshRecordState state,
  }) {
    return <String, dynamic>{
      'state': state.wire,
      'relays': m.relays,
    };
  }

  /// Applies a decoded body onto a [DmConversationModel] (creates one if
  /// [existing] is null). Caller sets `signedNostrEvent` + `removedAt` per
  /// the winning event's state.
  static DmConversationModel applyBody(
    Map<String, dynamic> body, {
    required String otherPubkey,
    DmConversationModel? existing,
  }) {
    final row = existing ?? DmConversationModel();
    row.otherPubkey = otherPubkey;
    row.relays = _asStringList(body['relays']);
    return row;
  }

  static List<String> _asStringList(Object? v) =>
      v is List ? v.whereType<String>().toList() : const <String>[];
}
