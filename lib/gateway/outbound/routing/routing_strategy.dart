import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/event_queue_model.dart';

/// One strategy per category of Nostr event (channel, DM, private channel, ...).
///
/// [EventRouter] iterates strategies in order; first [matches] wins.
/// [resolveTargets] returns the list of relay URLs the event should be sent to,
/// or `null` to mean "send to all persistent main relays" (the default behavior).
abstract class RoutingStrategy {
  bool matches(EventQueueModel event);
  Future<List<String>?> resolveTargets(EventQueueModel event, Isar isar);
}
