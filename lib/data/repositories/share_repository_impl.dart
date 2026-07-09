import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/notes/embedded_note_codec.dart';
import 'package:uniun/core/notes/imeta_builder.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/domain/entities/media/media_blob_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/inputs/share_note_input.dart';
import 'package:uniun/domain/repositories/share_repository.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/media_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

/// Dispatcher only — every destination publishes through its existing kind-
/// specific use case. The shared note is carried by value as an
/// `embeddedNoteJson` snapshot (see [EmbeddedNoteCodec]); the user's composed
/// text / references / images ride alongside as a normal note. No new publish
/// path.
@Injectable(as: ShareRepository)
class ShareRepositoryImpl implements ShareRepository {
  final GetActiveUserKeysUseCase _getKeys;
  final PublishMediaNoteUseCase _publishFeed;
  final CreateGroupMessageUseCase _publishGroup;
  final SendDmUseCase _publishDm;
  final SendPrivateGroupMessageUsecase _publishPrivateGroup;

  ShareRepositoryImpl(
    this._getKeys,
    this._publishFeed,
    this._publishGroup,
    this._publishDm,
    this._publishPrivateGroup,
  );

  @override
  Future<Either<Failure, Unit>> shareNote(ShareNoteInput input) async {
    try {
      // The note is passed in from the UI (every share button already renders a
      // NoteEntity) — no re-resolution, so any store that backs a NoteCard is
      // shareable, including the ephemeral Surrounding (mesh) collection.
      final source = input.source;
      final keysResult = await _getKeys();
      return await keysResult.fold(
        (f) async => Left(f),
        (keys) async {
          // Double-nest guard: if the shared note is itself a share, embed
          // the genuine inner original so quotedNote stays one level deep.
          final snapshotSource = source.quotedNote ?? source;
          final snapshotJson =
              EmbeddedNoteCodec.encodeFromEntity(snapshotSource);
          final content = input.content.trim();

          switch (input.destination) {
            case ShareToFeed():
              return _dispatchFeed(
                keys: keys,
                content: content,
                referenceIds: input.referenceIds,
                attachments: input.attachments,
                snapshotJson: snapshotJson,
              );
            case ShareToPublicGroup(groupId: final id):
              return _dispatchGroup(
                privkey: keys.privkeyHex,
                groupId: id,
                content: content,
                referenceIds: input.referenceIds,
                attachments: input.attachments,
                snapshotJson: snapshotJson,
              );
            case ShareToPrivateGroup(groupId: final id):
              return _dispatchPrivateGroup(
                keys: keys,
                groupId: id,
                content: content,
                referenceIds: input.referenceIds,
                attachments: input.attachments,
                snapshotJson: snapshotJson,
              );
            case ShareToDm(otherPubkeyHex: final pubkey):
              return _dispatchDm(
                otherPubkey: pubkey,
                content: content,
                referenceIds: input.referenceIds,
                attachments: input.attachments,
                snapshotJson: snapshotJson,
              );
          }
        },
      );
    } catch (e) {
      return Left(Failure.errorFailure(e.toString()));
    }
  }

  Future<Either<Failure, Unit>> _dispatchFeed({
    required UserSigningKeys keys,
    required String content,
    required List<String> referenceIds,
    required List<MediaBlobEntity> attachments,
    required String snapshotJson,
  }) async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hashtags = _hashtags(content);
    // Canonical order (see EventQueueModel.toSerializedRelayMessage):
    //   e mention… → t… → embeddedNoteJson → imeta…
    final tags = <List<String>>[
      for (final id in referenceIds) ['e', id, '', 'mention'],
      for (final h in hashtags) ['t', h],
      EmbeddedNoteCodec.tag(snapshotJson),
      ...buildImetaTags(attachments),
    ];
    final event = Event.from(
      privkey: keys.privkeyHex,
      kind: 1,
      content: content,
      tags: tags,
      createdAt: nowUnix,
    );
    final entity = NoteEntity(
      id: event.id,
      sig: event.sig,
      authorPubkey: event.pubkey,
      content: content,
      kind: kNoteKind,
      type: _typeFor(attachments),
      eTagRefs: List<String>.from(referenceIds),
      pTagRefs: const [],
      tTags: hashtags,
      created: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      embeddedNoteJson: snapshotJson,
      attachments: attachments,
    );
    final result = await _publishFeed(
      PublishMediaNoteInput(note: entity, attachments: attachments),
    );
    return result.fold((f) => Left(f), (_) => const Right(unit));
  }

  Future<Either<Failure, Unit>> _dispatchGroup({
    required String privkey,
    required String groupId,
    required String content,
    required List<String> referenceIds,
    required List<MediaBlobEntity> attachments,
    required String snapshotJson,
  }) async {
    final result = await _publishGroup(
      CreateGroupMessageInput(
        groupId: groupId,
        content: content,
        privateKey: privkey,
        mentionRefs: referenceIds,
        embeddedNoteJson: snapshotJson,
        attachments: attachments,
      ),
    );
    return result.fold((f) => Left(f), (_) => const Right(unit));
  }

  Future<Either<Failure, Unit>> _dispatchPrivateGroup({
    required UserSigningKeys keys,
    required String groupId,
    required String content,
    required List<String> referenceIds,
    required List<MediaBlobEntity> attachments,
    required String snapshotJson,
  }) async {
    await _publishPrivateGroup.execute(
      groupId: groupId,
      content: content,
      authorPubkey: keys.pubkeyHex,
      privkeyHex: keys.privkeyHex,
      mentionRefs: referenceIds,
      embeddedNoteJson: snapshotJson,
      attachments: attachments,
    );
    return const Right(unit);
  }

  Future<Either<Failure, Unit>> _dispatchDm({
    required String otherPubkey,
    required String content,
    required List<String> referenceIds,
    required List<MediaBlobEntity> attachments,
    required String snapshotJson,
  }) async {
    final result = await _publishDm(
      SendDmParams(
        otherPubkey: otherPubkey,
        content: content,
        type: _typeFor(attachments),
        mentionRefs: referenceIds,
        embeddedNoteJson: snapshotJson,
        attachments: attachments,
      ),
    );
    return result.fold((f) => Left(f), (_) => const Right(unit));
  }

  NoteType _typeFor(List<MediaBlobEntity> attachments) =>
      attachments.any((a) => a.mime.startsWith('image/'))
          ? NoteType.image
          : NoteType.text;

  List<String> _hashtags(String content) => RegExp(r'#(\w+)')
      .allMatches(content)
      .map((m) => m.group(1)!)
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();
}
