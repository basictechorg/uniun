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
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/get_groups_usecase.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
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
/// dispatches group/DM/private through the same use cases the outbound share
/// uses — with `embeddedNoteJson: null`, since there is no source note to embed.
@injectable
class ReceiveShareBloc extends Bloc<ReceiveShareEvent, ReceiveShareState> {
  final GetGroupsUseCase _getGroups;
  final GetPrivateGroupsUsecase _getPrivateGroups;
  final GetDmConversationsUseCase _getDms;
  final GetActiveUserUseCase _getActiveUser;
  final GetActiveUserKeysUseCase _getKeys;
  final UploadMediaUseCase _uploadMedia;
  final SaveLocalMediaUseCase _saveLocalMedia;
  final PublishNoteUseCase _publishNote;
  final PublishMediaNoteUseCase _publishMediaNote;
  final CreateGroupMessageUseCase _publishGroup;
  final SendDmUseCase _publishDm;
  final SendPrivateGroupMessageUsecase _publishPrivateGroup;
  final SaveDraftUseCase _saveDraft;

  ReceiveShareBloc(
    this._getGroups,
    this._getPrivateGroups,
    this._getDms,
    this._getActiveUser,
    this._getKeys,
    this._uploadMedia,
    this._saveLocalMedia,
    this._publishNote,
    this._publishMediaNote,
    this._publishGroup,
    this._publishDm,
    this._publishPrivateGroup,
    this._saveDraft,
  ) : super(const ReceiveShareState()) {
    on<InitReceiveShare>(_onInit, transformer: droppable());
    on<ReceiveContentChanged>(
        (e, emit) => emit(state.copyWith(content: e.value)));
    on<AttachReceiveMedia>(_onAttachMedia, transformer: sequential());
    on<RemoveReceiveMedia>((e, emit) => emit(state.copyWith(
          pending: state.pending.where((m) => m.sha256 != e.sha256).toList(),
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

    final groupsResult = await _getGroups();
    final publicGroups = groupsResult.fold<List<GroupEntity>>(
      (_) => const [],
      (list) => list,
    );

    final privateGroups = await _getPrivateGroups
        .execute()
        .first
        .catchError((_) => const <PrivateGroupEntity>[]);

    final dmsResult = await _getDms();
    final dms = dmsResult.fold<List<DmConversationEntity>>(
      (_) => const [],
      (list) => list,
    );

    emit(state.copyWith(
      loading: false,
      authorPubkey: authorPubkey,
      publicGroups: publicGroups,
      privateGroups: privateGroups,
      dmConversations: dms,
      ingesting: incoming.files.isNotEmpty,
    ));

    // Ingest shared media: read → compress into PickedMedia. No upload here —
    // pushed to Blossom on submit. Sequential to bound peak memory on a large
    // multi-file share.
    for (final f in incoming.files) {
      final picked = await sharedFileToPicked(path: f.path, mimeType: f.mimeType);
      if (picked == null) continue;
      if (state.pending.any((m) => m.sha256 == picked.sha256)) continue;
      emit(state.copyWith(pending: [...state.pending, picked]));
    }

    emit(state.copyWith(ingesting: false));
  }

  void _onAttachMedia(
      AttachReceiveMedia event, Emitter<ReceiveShareState> emit) {
    // No upload here — pushed to Blossom on submit. Hold the prepared pick.
    if (state.pending.any((m) => m.sha256 == event.media.sha256)) return;
    emit(state.copyWith(pending: [...state.pending, event.media]));
  }

  Future<void> _onSaveDraft(
      SaveReceiveDraft event, Emitter<ReceiveShareState> emit) async {
    final content = state.content.trim();
    if (content.isEmpty && state.pending.isEmpty) {
      emit(state.copyWith(error: 'draft-needs-text'));
      return;
    }

    // Stage attached media on-device only — the bytes are uploaded to Blossom
    // when the draft is published, not now. A staging failure aborts the save.
    final staged = <MediaBlobEntity>[];
    for (final media in state.pending) {
      final res = await _saveLocalMedia(SaveLocalMediaInput(
        bytes: media.bytes,
        mime: media.mime,
        filename: media.filename,
        blurhash: media.blurhash,
        width: media.width,
        height: media.height,
      ));
      final blob = res.fold((_) => null, (b) => b);
      if (blob == null) {
        emit(state.copyWith(error: res.fold((f) => f.toString(), (_) => '')));
        return;
      }
      staged.add(blob);
    }

    final draft = DraftEntity(
      draftId: const Uuid().v4(),
      content: content,
      eTagRefs: [for (final r in state.references) r.id],
      pTagRefs: const [],
      tTags: extractHashtags(content),
      attachments: staged,
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
    if (content.isEmpty && state.pending.isEmpty) {
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

    final referenceIds = [for (final r in state.references) r.id];

    try {
      switch (event.destination) {
        case ShareToFeed():
          await _publishFeed(keys, content, referenceIds, attachments);
        case ShareToPublicGroup(groupId: final id):
          await _publishGroup(CreateGroupMessageInput(
            groupId: id,
            content: content,
            privateKey: keys.privkeyHex,
            mentionRefs: referenceIds,
            attachments: attachments,
          ));
        case ShareToPrivateGroup(groupId: final id):
          await _publishPrivateGroup.execute(
            groupId: id,
            content: content,
            authorPubkey: keys.pubkeyHex,
            privkeyHex: keys.privkeyHex,
            mentionRefs: referenceIds,
            attachments: attachments,
          );
        case ShareToDm(otherPubkeyHex: final pubkey):
          await _publishDm(SendDmParams(
            otherPubkey: pubkey,
            content: content,
            type: _typeFor(attachments),
            mentionRefs: referenceIds,
            attachments: attachments,
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
    UserSigningKeys keys,
    String content,
    List<String> referenceIds,
    List<MediaBlobEntity> attachments,
  ) async {
    final hashtags = extractHashtags(content);
    final tags = buildNoteTags(
      mentionIds: referenceIds,
      hashtags: hashtags,
    );
    if (attachments.isNotEmpty) {
      tags.addAll(buildImetaTags(attachments));
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
      type: _typeFor(attachments),
      attachments: attachments,
    );
    final result = attachments.isEmpty
        ? await _publishNote.call(note)
        : await _publishMediaNote.call(
            PublishMediaNoteInput(note: note, attachments: attachments),
          );
    result.fold((f) => throw Exception(f.toString()), (_) {});
  }

  NoteType _typeFor(List<MediaBlobEntity> attachments) =>
      attachments.any((a) => a.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text;
}
