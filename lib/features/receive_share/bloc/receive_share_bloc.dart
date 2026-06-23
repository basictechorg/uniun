import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/common/widgets/composer/uniun_composer.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/usecases/create_channel_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/get_channels_usecase.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';
import 'package:uniun/features/receive_share/widgets/shared_incoming.dart';

part 'receive_share_event.dart';
part 'receive_share_state.dart';
part 'receive_share_bloc.freezed.dart';

/// Drives the receive-share sheet: takes content shared INTO UNIUN from another
/// app, lets the user compose around it, and publishes it as a brand-new note
/// to the chosen destination — or saves it as a draft.
///
/// Mirrors [ShareSheetBloc] for destination loading + media, but publishes via
/// the Brahma path (sign → [PublishNoteUseCase] / [PublishMediaNoteUseCase]) and
/// dispatches channel/DM/private through the same use cases the outbound share
/// uses — with `embeddedNoteJson: null`, since there is no source note to embed.
@injectable
class ReceiveShareBloc extends Bloc<ReceiveShareEvent, ReceiveShareState> {
  final GetChannelsUseCase _getChannels;
  final GetPrivateChannelsUsecase _getPrivateChannels;
  final GetDmConversationsUseCase _getDms;
  final GetActiveUserUseCase _getActiveUser;
  final GetActiveUserKeysUseCase _getKeys;
  final UploadMediaUseCase _uploadMedia;
  final PublishNoteUseCase _publishNote;
  final PublishMediaNoteUseCase _publishMediaNote;
  final CreateChannelMessageUseCase _publishChannel;
  final SendDmUseCase _publishDm;
  final SendPrivateChannelMessageUsecase _publishPrivateChannel;
  final SaveDraftUseCase _saveDraft;

  ReceiveShareBloc(
    this._getChannels,
    this._getPrivateChannels,
    this._getDms,
    this._getActiveUser,
    this._getKeys,
    this._uploadMedia,
    this._publishNote,
    this._publishMediaNote,
    this._publishChannel,
    this._publishDm,
    this._publishPrivateChannel,
    this._saveDraft,
  ) : super(const ReceiveShareState()) {
    on<InitReceiveShare>(_onInit, transformer: droppable());
    on<ReceiveContentChanged>(
        (e, emit) => emit(state.copyWith(content: e.value)));
    on<AttachReceiveMedia>(_onAttachMedia, transformer: sequential());
    on<RemoveReceiveMedia>((e, emit) => emit(state.copyWith(
          attachments:
              state.attachments.where((a) => a.sha256 != e.sha256).toList(),
        )));
    on<SetReceiveReferences>(
        (e, emit) => emit(state.copyWith(references: e.references)));
    on<RemoveReceiveReference>((e, emit) => emit(state.copyWith(
          references: state.references.where((r) => r.id != e.id).toList(),
        )));
    on<SaveReceiveDraft>(_onSaveDraft, transformer: droppable());
    on<SubmitReceiveShare>(_onSubmit, transformer: droppable());
  }

  Future<void> _onInit(
      InitReceiveShare event, Emitter<ReceiveShareState> emit) async {
    final incoming = event.incoming;
    emit(state.copyWith(
      loading: true,
      error: null,
      content: incoming.text ?? '',
    ));

    // Load destinations (same chain as ShareSheetBloc).
    final userResult = await _getActiveUser();
    final authorPubkey = userResult.fold((_) => '', (u) => u.pubkeyHex);

    final channelsResult = await _getChannels();
    final publicChannels = channelsResult.fold<List<ChannelEntity>>(
      (_) => const [],
      (list) => list,
    );

    final privateChannels = await _getPrivateChannels
        .execute()
        .first
        .catchError((_) => const <PrivateChannelEntity>[]);

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
      ingesting: incoming.files.isNotEmpty,
    ));

    // Ingest shared media: read → compress → upload to Blossom. Sequential so
    // we don't thrash the upload server with a large multi-file share.
    for (final f in incoming.files) {
      final picked = await sharedFileToPicked(path: f.path, mimeType: f.mimeType);
      if (picked == null) continue;
      final result = await _uploadMedia(UploadMediaInput(
        bytes: picked.bytes,
        mime: picked.mime,
        filename: picked.filename,
        width: picked.width,
        height: picked.height,
      ));
      result.fold(
        (_) {},
        (blob) {
          if (state.attachments.any((a) => a.sha256 == blob.sha256)) return;
          emit(state.copyWith(attachments: [...state.attachments, blob]));
        },
      );
    }

    emit(state.copyWith(ingesting: false));
  }

  Future<void> _onAttachMedia(
      AttachReceiveMedia event, Emitter<ReceiveShareState> emit) async {
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
      (blob) {
        if (state.attachments.any((a) => a.sha256 == blob.sha256)) {
          emit(state.copyWith(uploading: false));
          return;
        }
        emit(state.copyWith(
          uploading: false,
          attachments: [...state.attachments, blob],
        ));
      },
    );
  }

  Future<void> _onSaveDraft(
      SaveReceiveDraft event, Emitter<ReceiveShareState> emit) async {
    final content = state.content.trim();
    // Drafts are text-only (DraftEntity carries no media). Require text.
    if (content.isEmpty) {
      emit(state.copyWith(error: 'draft-needs-text'));
      return;
    }
    final draft = DraftEntity(
      draftId: const Uuid().v4(),
      content: content,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: extractHashtags(content),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final result = await _saveDraft.call(draft);
    result.fold(
      (f) => emit(state.copyWith(error: f.toString())),
      (_) => emit(state.copyWith(draftSaved: true)),
    );
  }

  Future<void> _onSubmit(
      SubmitReceiveShare event, Emitter<ReceiveShareState> emit) async {
    if (state.submitting) return;
    final content = state.content.trim();
    if (content.isEmpty && state.attachments.isEmpty) {
      emit(state.copyWith(error: 'nothing-to-share'));
      return;
    }
    emit(state.copyWith(submitting: true, error: null));

    final keysResult = await _getKeys();
    final keys = keysResult.fold<UserSigningKeys?>((_) => null, (k) => k);
    if (keys == null) {
      emit(state.copyWith(
          submitting: false,
          error: keysResult.fold((f) => f.toString(), (_) => '')));
      return;
    }

    final referenceIds = [for (final r in state.references) r.id];

    try {
      switch (event.destination) {
        case ShareToFeed():
          await _publishFeed(keys, content, referenceIds);
        case ShareToPublicChannel(channelId: final id):
          await _publishChannel(CreateChannelMessageInput(
            channelId: id,
            content: content,
            privateKey: keys.privkeyHex,
            mentionRefs: referenceIds,
            attachments: state.attachments,
          ));
        case ShareToPrivateChannel(groupId: final id):
          await _publishPrivateChannel.execute(
            groupId: id,
            content: content,
            authorPubkey: keys.pubkeyHex,
            privkeyHex: keys.privkeyHex,
            mentionRefs: referenceIds,
            attachments: state.attachments,
          );
        case ShareToDm(otherPubkeyHex: final pubkey):
          await _publishDm(SendDmParams(
            otherPubkey: pubkey,
            content: content,
            type: _typeFor(state.attachments),
            mentionRefs: referenceIds,
            attachments: state.attachments,
          ));
      }
      emit(state.copyWith(submitting: false, submitted: true));
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }

  /// Publishes a brand-new Kind 1 note on the user's feed — the Brahma path.
  /// No `embeddedNoteJson`: this is fresh content, not a quote.
  Future<void> _publishFeed(
      UserSigningKeys keys, String content, List<String> referenceIds) async {
    final hashtags = extractHashtags(content);
    final tags = buildNoteTags(
      mentionIds: referenceIds,
      hashtags: hashtags,
    );
    if (state.attachments.isNotEmpty) {
      tags.addAll(buildImetaTags(state.attachments));
    }
    final signed = signNostrEvent(
      content: content,
      tags: tags,
      privkeyHex: keys.privkeyHex,
    );
    final note = noteEntityFromEvent(
      event: signed,
      pubkeyHex: keys.pubkeyHex,
      eTagRefs: referenceIds,
      tTags: hashtags,
    ).copyWith(
      type: _typeFor(state.attachments),
      attachments: state.attachments,
    );
    final result = state.attachments.isEmpty
        ? await _publishNote.call(note)
        : await _publishMediaNote.call(
            PublishMediaNoteInput(note: note, attachments: state.attachments),
          );
    result.fold((f) => throw Exception(f.toString()), (_) {});
  }

  NoteType _typeFor(List<MediaBlobEntity> attachments) =>
      attachments.any((a) => a.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text;
}
