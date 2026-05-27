import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/gateway/outbound/routing/routing_strategy.dart';

/// Resolves the target relay URLs for an outbound [EventQueueModel].
///
/// Returns `null` to mean "send to all persistent main relays" — i.e. the
/// default fanout used for kind 1 notes and anything else without a custom
/// strategy match.
class EventRouter {
  final Isar _isar;
  final List<RoutingStrategy> _strategies;

  EventRouter({required Isar isar, required List<RoutingStrategy> strategies})
      : _isar = isar,
        _strategies = strategies;

  Future<List<String>?> resolveTargets(EventQueueModel event) async {
    for (final s in _strategies) {
      if (s.matches(event)) return s.resolveTargets(event, _isar);
    }
    return null;
  }
}
