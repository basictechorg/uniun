import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/get_channels_usecase.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/share_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';
part 'share_sheet_bloc.freezed.dart';

@injectable
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  final GetChannelsUseCase _getChannels;
  final GetPrivateChannelsUsecase _getPrivateChannels;
  final GetDmConversationsUseCase _getDms;
  final ShareNoteUseCase _shareNote;
  final UploadMediaUseCase _uploadMedia;
  final GetActiveUserUseCase _getActiveUser;

  ShareSheetBloc(
    this._getChannels,
    this._getPrivateChannels,
    this._getDms,
    this._shareNote,
    this._uploadMedia,
    this._getActiveUser,
  ) : super(const ShareSheetState()) {
    on<LoadDestinations>(_onLoad);
    on<ContentChanged>((e, emit) => emit(state.copyWith(content: e.value)));
    on<SetReferences>((e, emit) => emit(state.copyWith(references: e.references)));
    on<RemoveReference>((e, emit) => emit(state.copyWith(
          references:
              state.references.where((r) => r.id != e.id).toList(),
        )));
    on<AttachMedia>(_onAttachMedia);
    on<RemoveMedia>((e, emit) => emit(state.copyWith(
          attachments:
              state.attachments.where((a) => a.sha256 != e.sha256).toList(),
        )));
    on<SubmitShare>(_onSubmit);
  }

  Future<void> _onLoad(LoadDestinations event, Emitter<ShareSheetState> emit) async {
    emit(state.copyWith(loading: true, error: null));

    final userResult = await _getActiveUser();
    final authorPubkey =
        userResult.fold((_) => '', (u) => u.pubkeyHex);

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
      authorPubkey: authorPubkey,
      publicChannels: publicChannels,
      privateChannels: privateChannels,
      dmConversations: dms,
    ));
  }

  Future<void> _onAttachMedia(
      AttachMedia event, Emitter<ShareSheetState> emit) async {
    emit(state.copyWith(uploading: true, error: null));
    final result = await _uploadMedia(UploadMediaInput(
      bytes: event.bytes,
      mime: event.mime,
      filename: event.filename,
      width: event.width,
      height: event.height,
    ));
    result.fold(
      (f) => emit(state.copyWith(uploading: false, error: f.toString())),
      (blob) => emit(state.copyWith(
        uploading: false,
        attachments: [...state.attachments, blob],
      )),
    );
  }

  Future<void> _onSubmit(SubmitShare event, Emitter<ShareSheetState> emit) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, error: null));
    final result = await _shareNote(
      ShareNoteInput(
        sourceEventId: event.sourceEventId,
        destination: event.destination,
        content: state.content,
        referenceIds: [for (final r in state.references) r.id],
        attachments: state.attachments,
      ),
    );
    result.fold(
      (f) => emit(state.copyWith(submitting: false, error: f.toString())),
      (_) => emit(state.copyWith(submitting: false, submitted: true)),
    );
  }
}
