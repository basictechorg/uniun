import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/channel_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/private_channel_model.dart';
import 'package:uniun/data/models/relay_model.dart';

/// Hooks for the orchestrator. Plain function fields rather than callbacks so
/// the wiring stays readable at the call site.
class WatcherHandlers {
  final Future<void> Function() onQueueChanged;
  final Future<void> Function() onRelayModelsChanged;
  final Future<void> Function() onFollowedNotesChanged;
  final Future<void> Function() onMissingProfilesChanged;
  final Future<void> Function() onChannelsChangedAdditive;
  final Future<void> Function() onPrivateChannelsChangedAdditive;

  const WatcherHandlers({
    required this.onQueueChanged,
    required this.onRelayModelsChanged,
    required this.onFollowedNotesChanged,
    required this.onMissingProfilesChanged,
    required this.onChannelsChangedAdditive,
    required this.onPrivateChannelsChangedAdditive,
  });
}

/// Consolidates every `watchLazy()` subscription the gateway needs.
///
/// Replaces the five separate stream subscriptions on [CentralRelayManager].
/// Channel and PrivateChannel watchers are gated on count-increase so metadata
/// updates don't trigger resubscribes — matches the `_knownChannelCount` hack
/// in the original code, but expressed once instead of duplicated.
class IsarWatcherHub {
  final Isar _isar;
  final WatcherHandlers _handlers;

  final List<StreamSubscription<void>> _subs = [];
  int _knownChannelCount = 0;
  int _knownPrivateChannelCount = 0;

  IsarWatcherHub({required Isar isar, required WatcherHandlers handlers})
      : _isar = isar,
        _handlers = handlers;

  Future<void> start() async {
    _knownChannelCount = await _isar.channelModels.count();
    _knownPrivateChannelCount = await _isar.privateChannelModels.count();

    _subs.add(_isar.eventQueueModels.watchLazy().listen((_) async {
      await _handlers.onQueueChanged();
    }));

    _subs.add(_isar.relayModels.watchLazy().listen((_) async {
      await _handlers.onRelayModelsChanged();
    }));

    _subs.add(_isar.followedNoteModels.watchLazy().listen((_) async {
      await _handlers.onFollowedNotesChanged();
    }));

    _subs.add(_isar.missingProfilePubkeyModels.watchLazy().listen((_) async {
      await _handlers.onMissingProfilesChanged();
    }));

    _subs.add(_isar.channelModels.watchLazy().listen((_) async {
      final current = await _isar.channelModels.count();
      if (current <= _knownChannelCount) {
        _knownChannelCount = current;
        return;
      }
      _knownChannelCount = current;
      await _handlers.onChannelsChangedAdditive();
    }));

    _subs.add(_isar.privateChannelModels.watchLazy().listen((_) async {
      final current = await _isar.privateChannelModels.count();
      if (current <= _knownPrivateChannelCount) {
        _knownPrivateChannelCount = current;
        return;
      }
      _knownPrivateChannelCount = current;
      await _handlers.onPrivateChannelsChangedAdditive();
    }));
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
