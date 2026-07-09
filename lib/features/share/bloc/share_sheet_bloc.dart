import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/get_groups_usecase.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/share_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'share_sheet_event.dart';
part 'share_sheet_state.dart';
part 'share_sheet_bloc.freezed.dart';

@injectable
class ShareSheetBloc extends Bloc<ShareSheetEvent, ShareSheetState> {
  final GetGroupsUseCase _getGroups;
  final GetPrivateGroupsUsecase _getPrivateGroups;
  final GetDmConversationsUseCase _getDms;
  final ShareNoteUseCase _shareNote;
  final UploadMediaUseCase _uploadMedia;
  final GetActiveUserUseCase _getActiveUser;

  ShareSheetBloc(
    this._getGroups,
    this._getPrivateGroups,
    this._getDms,
    this._shareNote,
    this._uploadMedia,
    this._getActiveUser,
  ) : super(const ShareSheetState()) {
    on<LoadDestinations>(_onLoad);
    on<SelectDestination>(
        (e, emit) => emit(state.copyWith(selectedDestination: e.destination)));
    on<ContentChanged>((e, emit) => emit(state.copyWith(content: e.value)));
    on<SetReferences>((e, emit) => emit(state.copyWith(references: e.references)));
    on<RemoveReference>((e, emit) => emit(state.copyWith(
          references:
              state.references.where((r) => r.id != e.id).toList(),
        )));
    on<AttachMedia>(_onAttachMedia);
    on<RemoveMedia>((e, emit) => emit(state.copyWith(
          pending:
              state.pending.where((m) => m.sha256 != e.sha256).toList(),
        )));
    on<SubmitShare>(_onSubmit);
  }

  Future<void> _onLoad(LoadDestinations event, Emitter<ShareSheetState> emit) async {
    emit(state.copyWith(loading: true, error: null));

    final userResult = await _getActiveUser();
    final authorPubkey =
        userResult.fold((_) => '', (u) => u.pubkeyHex);

    final groupsResult = await _getGroups();
    final publicGroups = groupsResult.fold<List<GroupEntity>>(
      (_) => const [],
      (list) => list,
    );

    final privateGroups =
        await _getPrivateGroups.execute().first.catchError(
              (_) => const <PrivateGroupEntity>[],
            );

    final dmsResult = await _getDms();
    final dms = dmsResult.fold<List<DmConversationEntity>>(
      (_) => const [],
      (list) => list,
    );

    // The source note is carried in directly — no re-resolution.
    final quotedNote = event.source;

    emit(state.copyWith(
      loading: false,
      authorPubkey: authorPubkey,
      publicGroups: publicGroups,
      privateGroups: privateGroups,
      dmConversations: dms,
      quotedNote: quotedNote,
    ));
  }

  void _onAttachMedia(AttachMedia event, Emitter<ShareSheetState> emit) {
    // No upload here — pushed to Blossom on submit. Hold the prepared pick.
    if (state.pending.any((m) => m.sha256 == event.media.sha256)) return;
    emit(state.copyWith(pending: [...state.pending, event.media]));
  }

  Future<void> _onSubmit(SubmitShare event, Emitter<ShareSheetState> emit) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, error: null));

    // Upload pending attachments now (deferred from attach time). A failure
    // aborts the share but keeps the picks so the user can retry.
    final attachments = <MediaBlobEntity>[];
    for (final media in state.pending) {
      final up = await _uploadMedia(UploadMediaInput(
        bytes: media.bytes,
        mime: media.mime,
        filename: media.filename,
        blurhash: media.blurhash,
        width: media.width,
        height: media.height,
      ));
      final blob = up.fold((_) => null, (b) => b);
      if (blob == null) {
        emit(state.copyWith(
            submitting: false, error: up.fold((f) => f.toString(), (_) => '')));
        return;
      }
      attachments.add(blob);
    }

    final result = await _shareNote(
      ShareNoteInput(
        source: event.source,
        destination: event.destination,
        content: state.content,
        referenceIds: [for (final r in state.references) r.id],
        attachments: attachments,
      ),
    );
    result.fold(
      (f) => emit(state.copyWith(submitting: false, error: f.toString())),
      (_) => emit(state.copyWith(submitting: false, submitted: true)),
    );
  }
}
