import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/data/models/followed_user_model.dart';
import 'package:uniun/domain/entities/followed_user/followed_user_entity.dart';
import 'package:uniun/domain/usecases/followed_user_usecases.dart';
import 'package:uniun/domain/usecases/followed_note_usecases.dart';
import 'package:uniun/domain/usecases/get_channels_usecase.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/followed_note_model.dart';
import 'package:uniun/data/models/profile_model.dart';
import 'dart:async';

part 'drawer_event.dart';
part 'drawer_state.dart';

@injectable
class DrawerBloc extends Bloc<DrawerEvent, DrawerState> {
  final GetActiveUserUseCase _getActiveUser;
  final GetOwnProfileUseCase _getOwnProfile;
  final GetAllFollowedNotesUseCase _getAllFollowedNotes;
  final GetChannelsUseCase _getChannels;
  final GetPrivateChannelsUsecase _getPrivateChannels;
  final GetFollowedUsersUseCase _getFollowedUsers;
  final GetRelaysUseCase _getRelays;
  final Isar _isar;
  StreamSubscription<void>? _dmWatcher;
  StreamSubscription<void>? _privateChannelWatcher;
  StreamSubscription<void>? _followedUsersWatcher;
  StreamSubscription<void>? _followedNotesWatcher;

  DrawerBloc(
    this._getActiveUser,
    this._getOwnProfile,
    this._getAllFollowedNotes,
    this._getChannels,
    this._getPrivateChannels,
    this._getFollowedUsers,
    this._getRelays,
    this._isar,
  ) : super(DrawerInitial()) {
    on<DrawerLoadEvent>(_onLoad);

    _privateChannelWatcher = _getPrivateChannels.execute().listen((_) {
      if (!isClosed) add(DrawerLoadEvent());
    });
    _followedUsersWatcher = _isar.followedUserModels.watchLazy().listen((_) {
      if (!isClosed) add(DrawerLoadEvent());
    });
    // Reactive "Following" section: follow/unfollow from a NoteCard writes to
    // followedNoteModels, and the gateway bumps newReferenceCount here.
    _followedNotesWatcher = _isar.followedNoteModels.watchLazy().listen((_) {
      if (!isClosed) add(DrawerLoadEvent());
    });
  }

  Future<void> _onLoad(
    DrawerLoadEvent event,
    Emitter<DrawerState> emit,
  ) async {
    _dmWatcher ??= _isar.dmConversationModels.watchLazy().listen((_) {
      if (!isClosed) {
        add(DrawerLoadEvent());
      }
    });

    emit(DrawerLoading());

    try {
      final userResult = await _getActiveUser.call();
      final user = userResult.fold((_) => null, (u) => u);

      String displayName = 'Anonymous';
      String npub = '';
      String? avatarUrl;

      if (user != null) {
        // Keep the FULL npub in state. UI is responsible for truncating
        // for display only — Copy must always paste the complete value.
        npub = user.npub;

        final profileResult = await _getOwnProfile.call(user.pubkeyHex);
        final profile = profileResult.fold((_) => null, (p) => p);

        if (profile != null) {
          displayName = profile.name ?? profile.username ?? displayName;
          avatarUrl = profile.avatarUrl;
        }
      }

      // Live query for NIP-28 channels
      final channelsResult = await _getChannels.call();
      final channels = channelsResult.fold(
        (_) => <DrawerChannelItem>[],
        (list) => list
            .map((c) => DrawerChannelItem(
                  id: c.channelId,
                  name: c.name,
                  hasUnread: false, // Wait for DM / Channel message read tracking
                ))
            .toList(),
      );
      final dmConversations = await _isar.dmConversationModels.where().findAll();
      final dms = <DrawerDmItem>[];
      for (final conv in dmConversations) {
        final profile = await _isar.profileModels.where().pubkeyEqualTo(conv.otherPubkey).findFirst();
        dms.add(DrawerDmItem(
          pubkey: conv.otherPubkey,
          name: profile?.name ?? profile?.username ?? conv.otherPubkey,
          avatarUrl: profile?.avatarUrl,
        ));
      }

      final followedResult = await _getAllFollowedNotes.call();
      final followedNotes = followedResult.fold(
        (_) => <DrawerFollowedNoteItem>[],
        (list) => list
            .map((e) => DrawerFollowedNoteItem(
                  eventId: e.eventId,
                  contentPreview: e.contentPreview,
                  newReferenceCount: e.newReferenceCount,
                ))
            .toList(),
      );

      final privateChannelResult = await _getPrivateChannels.execute().first;
      final privateChannels = privateChannelResult.map((c) => DrawerPrivateChannelItem(
        id: c.groupId,
        name: c.name,
      )).toList();

      final followedUsersResult = await _getFollowedUsers.call();
      final List<FollowedUserEntity> followedUsersDomain =
          followedUsersResult.fold((_) => const [], (l) => l);
      final followedUsers = <DrawerFollowedUserItem>[];
      for (final f in followedUsersDomain) {
        final profile = await _isar.profileModels
            .where()
            .pubkeyEqualTo(f.pubkeyHex)
            .findFirst();
        final shortKey = f.pubkeyHex.length > 12
            ? '${f.pubkeyHex.substring(0, 12)}…'
            : f.pubkeyHex;
        followedUsers.add(DrawerFollowedUserItem(
          pubkey: f.pubkeyHex,
          name: profile?.name ?? profile?.username ?? f.petname ?? shortKey,
          avatarUrl: profile?.avatarUrl,
        ));
      }

      final relaysResult = await _getRelays.call();
      final myRelays = relaysResult.fold(
        (_) => <String>[],
        (list) => list.map((r) => r.url).toList(),
      );

      emit(DrawerLoaded(
        userName: displayName,
        npub: npub,
        pubkeyHex: user?.pubkeyHex ?? '',
        avatarUrl: avatarUrl,
        followedNotes: followedNotes,
        channels: channels,
        privateChannels: privateChannels,
        dms: dms,
        followedUsers: followedUsers,
        myRelays: myRelays,
      ));
    } catch (e) {
      emit(DrawerError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _dmWatcher?.cancel();
    _privateChannelWatcher?.cancel();
    _followedUsersWatcher?.cancel();
    _followedNotesWatcher?.cancel();
    return super.close();
  }
}
