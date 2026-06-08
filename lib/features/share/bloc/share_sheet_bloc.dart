import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/get_channels_usecase.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/share_usecases.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';
part 'share_sheet_bloc.freezed.dart';

@injectable
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  final GetChannelsUseCase _getChannels;
  final GetPrivateChannelsUsecase _getPrivateChannels;
  final GetDmConversationsUseCase _getDms;
  final ShareNoteUseCase _shareNote;

  ShareSheetBloc(
    this._getChannels,
    this._getPrivateChannels,
    this._getDms,
    this._shareNote,
  ) : super(const ShareSheetState()) {
    on<LoadDestinations>(_onLoad);
    on<CommentChanged>((e, emit) => emit(state.copyWith(comment: e.value)));
    on<SubmitShare>(_onSubmit);
  }

  Future<void> _onLoad(LoadDestinations event, Emitter<ShareSheetState> emit) async {
    emit(state.copyWith(loading: true, error: null));

    final channelsResult = await _getChannels();
    final publicChannels = channelsResult.fold<List<ChannelEntity>>(
      (_) => const [],
      (list) => list,
    );

    final privateChannels =
        await _getPrivateChannels.execute().first.catchError(
              (_) => const <PrivateChannelEntity>[],
            );

    final dmsResult = await _getDms();
    final dms = dmsResult.fold<List<DmConversationEntity>>(
      (_) => const [],
      (list) => list,
    );

    emit(state.copyWith(
      loading: false,
      publicChannels: publicChannels,
      privateChannels: privateChannels,
      dmConversations: dms,
    ));
  }

  Future<void> _onSubmit(SubmitShare event, Emitter<ShareSheetState> emit) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, error: null));
    final result = await _shareNote(
      ShareNoteInput(
        sourceEventId: event.sourceEventId,
        destination: event.destination,
        comment: state.comment,
      ),
    );
    result.fold(
      (f) => emit(state.copyWith(submitting: false, error: f.toString())),
      (_) => emit(state.copyWith(submitting: false, submitted: true)),
    );
  }
}
