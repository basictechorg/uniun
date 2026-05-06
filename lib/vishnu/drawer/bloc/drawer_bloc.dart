import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/usecases/followed_note_usecases.dart';
import 'package:uniun/domain/usecases/get_channels_usecase.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
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
  final Isar _isar;
  StreamSubscription<void>? _dmWatcher;
  StreamSubscription<void>? _privateChannelWatcher;

  DrawerBloc(
    this._getActiveUser,
    this._getOwnProfile,
    this._getAllFollowedNotes,
    this._getChannels,
    this._getPrivateChannels,
    this._isar,
  ) : super(DrawerInitial()) {
    on<DrawerLoadEvent>(_onLoad);
    
    _privateChannelWatcher = _getPrivateChannels.execute().listen((_) {
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
      String npubShort = '';
      String? avatarUrl;

      if (user != null) {
        npubShort = user.npub.length > 12
            ? '${user.npub.substring(0, 12)}...'
            : user.npub;

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

      emit(DrawerLoaded(
        userName: displayName,
        npub: npubShort,
        pubkeyHex: user?.pubkeyHex ?? '',
        avatarUrl: avatarUrl,
        followedNotes: followedNotes,
        channels: channels,
        privateChannels: privateChannels,
        dms: dms,
      ));
    } catch (e) {
      emit(DrawerError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _dmWatcher?.cancel();
    return super.close();
  }
}
