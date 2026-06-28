import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/data/models/missing_profile_pubkey_model.dart';
import 'package:uniun/data/models/private_group_model.dart';
import 'package:uniun/data/models/relay_model.dart';

/// Hooks for the orchestrator. Plain function fields rather than callbacks so
/// the wiring stays readable at the call site.
class WatcherHandlers {
  final Future<void> Function() onQueueChanged;
  final Future<void> Function() onRelayModelsChanged;
  final Future<void> Function() onFollowedNotesChanged;
  final Future<void> Function() onFollowedUsersChanged;
  final Future<void> Function() onMissingProfilesChanged;
  final Future<void> Function() onGroupsChangedAdditive;
  final Future<void> Function() onPrivateGroupsChangedAdditive;

  const WatcherHandlers({
    required this.onQueueChanged,
    required this.onRelayModelsChanged,
    required this.onFollowedNotesChanged,
    required this.onFollowedUsersChanged,
    required this.onMissingProfilesChanged,
    required this.onGroupsChangedAdditive,
    required this.onPrivateGroupsChangedAdditive,
  });
}

/// Consolidates every `watchLazy()` subscription the gateway needs.
///
/// Replaces the five separate stream subscriptions on [CentralRelayManager].
/// Group and PrivateGroup watchers are gated on count-increase so metadata
/// updates don't trigger resubscribes — matches the `_knownGroupCount` hack
/// in the original code, but expressed once instead of duplicated.
class IsarWatcherHub {
  final Isar _isar;
  final WatcherHandlers _handlers;

  final List<StreamSubscription<void>> _subs = [];
  int _knownGroupCount = 0;
  int _knownPrivateGroupCount = 0;

  IsarWatcherHub({required Isar isar, required WatcherHandlers handlers})
      : _isar = isar,
        _handlers = handlers;

  Future<void> start() async {
    _knownGroupCount = await _isar.groupModels.count();
    _knownPrivateGroupCount = await _isar.privateGroupModels.count();

    _subs.add(_isar.eventQueueModels.watchLazy().listen((_) async {
      await _handlers.onQueueChanged();
    }));

    _subs.add(_isar.relayModels.watchLazy().listen((_) async {
      await _handlers.onRelayModelsChanged();
    }));

    _subs.add(_isar.followedNoteModels.watchLazy().listen((_) async {
      await _handlers.onFollowedNotesChanged();
    }));

    _subs.add(_isar.followedUserModels.watchLazy().listen((_) async {
      await _handlers.onFollowedUsersChanged();
    }));

    _subs.add(_isar.missingProfilePubkeyModels.watchLazy().listen((_) async {
      await _handlers.onMissingProfilesChanged();
    }));

    _subs.add(_isar.groupModels.watchLazy().listen((_) async {
      final current = await _isar.groupModels.count();
      if (current <= _knownGroupCount) {
        _knownGroupCount = current;
        return;
      }
      _knownGroupCount = current;
      await _handlers.onGroupsChangedAdditive();
    }));

    _subs.add(_isar.privateGroupModels.watchLazy().listen((_) async {
      final current = await _isar.privateGroupModels.count();
      if (current <= _knownPrivateGroupCount) {
        _knownPrivateGroupCount = current;
        return;
      }
      _knownPrivateGroupCount = current;
      await _handlers.onPrivateGroupsChangedAdditive();
    }));
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
