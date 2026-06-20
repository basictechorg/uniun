import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr/nostr.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/gana_pending_output_model.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/repositories/event_queue_repository.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/domain/usecases/create_channel_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';

/// Main-isolate dispatcher that drains [GanaPendingOutputModel] rows produced
/// by the Gana engine and routes them through the existing publish use cases.
///
/// Why a main-isolate dispatcher instead of publishing from the engine:
///
///   1. DMs (NIP-17 gift wrap) and private channels (NIP-29 MLS) require
///      services with native plugins that are not safe to load in a
///      background isolate.
///   2. The publish use cases are wired into the main-isolate DI container;
///      moving them across isolates would mean duplicating the wiring.
///   3. The dispatcher pattern mirrors the gateway's inbound flow: engine
///      writes a row, main isolate observes via Isar `watchLazy()` and acts.
///
/// On success the dispatcher:
///   - stamps `outputEventId` on the matching `GanaRunModel`,
///   - deletes the pending row.
///
/// On failure it increments `attempts` and stores `lastError`. After
/// [_maxAttempts] failures it gives up, marks the matching run as `failed`,
/// and deletes the pending row.
@lazySingleton
class GanaOutputDispatcher {
  GanaOutputDispatcher(
    this._isar,
    this._userRepo,
    this._channelMessageUseCase,
    this._dmUseCase,
    this._privateChannelUseCase,
    this._eventQueueRepository,
  );

  final Isar _isar;
  final UserRepository _userRepo;
  final CreateChannelMessageUseCase _channelMessageUseCase;
  final SendDmUseCase _dmUseCase;
  final SendPrivateChannelMessageUsecase _privateChannelUseCase;
  final EventQueueRepository _eventQueueRepository;

  StreamSubscription<void>? _sub;
  bool _draining = false;
  bool _started = false;

  static const int _maxAttempts = 3;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    // Watch the pending queue for new rows.
    _sub = _isar.ganaPendingOutputModels
        .watchLazy(fireImmediately: true)
        .listen((_) => _drain());
    debugPrint('GanaOutputDispatcher started');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (true) {
        final next = await _isar.ganaPendingOutputModels
            .where()
            .sortByCreatedAt()
            .findFirst();
        if (next == null) return;
        await _processOne(next);
      }
    } catch (e, st) {
      debugPrint('GanaOutputDispatcher.drain unexpected error: $e\n$st');
    } finally {
      _draining = false;
    }
  }

  Future<void> _processOne(GanaPendingOutputModel row) async {
    try {
      final keys = await _userRepo.getActiveKeysHex();
      if (keys == null) {
        // No user logged in — leave the row in place; we'll retry when
        // they come back.
        await _bumpAttempt(row, 'no active user');
        // Don't loop forever — sleep then return so other ticks can wake us.
        return;
      }
      final eventId = await _publish(row, keys.privkeyHex, keys.pubkeyHex);
      await _stampRun(row.runId, eventId);
      await _isar.writeTxn(() async {
        await _isar.ganaPendingOutputModels.delete(row.id);
      });
    } catch (e, st) {
      debugPrint('GanaOutputDispatcher._processOne failed: $e\n$st');
      await _bumpAttempt(row, e.toString());
    }
  }

  Future<String> _publish(
    GanaPendingOutputModel row,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    switch (row.outputType) {
      case GanaOutputType.feed:
        return await _publishFeed(row, privkeyHex, pubkeyHex);
      case GanaOutputType.channel:
        return await _publishChannel(row, privkeyHex);
      case GanaOutputType.privateChannel:
        return await _publishPrivateChannel(row, privkeyHex, pubkeyHex);
      case GanaOutputType.dm:
        return await _publishDm(row, privkeyHex, pubkeyHex);
    }
  }

  // ── feed (kind 1) ────────────────────────────────────────────────────────
  Future<String> _publishFeed(
    GanaPendingOutputModel row,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final kind1 = Event.from(
      privkey: privkeyHex,
      kind: kNoteKind,
      content: row.body,
      tags: const <List<String>>[],
      createdAt: nowUnix,
    );
    final created = DateTime.fromMillisecondsSinceEpoch(kind1.createdAt * 1000);
    // Mirror PublishNoteUseCase: write to NoteModel for local UI visibility,
    // then enqueue for relay broadcast. Without the NoteModel write the
    // Gana's note would only appear in the feed if the relay echoes it back.
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(NoteModel(
        eventId: kind1.id,
        sig: kind1.sig,
        authorPubkey: kind1.pubkey,
        content: kind1.content,
        kind: kNoteKind,
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: created,
      ));
    });
    final res = await _eventQueueRepository.enqueueSignedEvent(
      eventId: kind1.id,
      authorPubkey: kind1.pubkey,
      sig: kind1.sig,
      kind: kNoteKind,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      content: kind1.content,
      created: created,
      serverTags: const [],
      imeta: const [],
    );
    return res.fold((f) => throw Exception(f.toString()), (_) => kind1.id);
  }

  // ── public channel (kind 42) ────────────────────────────────────────────
  Future<String> _publishChannel(
    GanaPendingOutputModel row,
    String privkeyHex,
  ) async {
    final channelId = row.outputChannelId;
    if (channelId == null) {
      throw StateError('channel outputType requires outputChannelId');
    }
    final res = await _channelMessageUseCase.call(CreateChannelMessageInput(
      channelId: channelId,
      content: row.body,
      privateKey: privkeyHex,
    ));
    return res.fold((f) => throw Exception(f.toString()), (note) => note.id);
  }

  // ── private channel (kind 9023, MLS) ────────────────────────────────────
  Future<String> _publishPrivateChannel(
    GanaPendingOutputModel row,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    final groupId = row.outputGroupId;
    if (groupId == null) {
      throw StateError('privateChannel outputType requires outputGroupId');
    }
    // `SendPrivateChannelMessageUsecase.execute` returns void, but the
    // transport service writes the resulting NoteModel synchronously before
    // returning. Snapshot the latest-self-authored note in this group
    // immediately after the call and use its `eventId`.
    final beforeId = await _latestSelfEventIdInGroup(groupId, pubkeyHex);
    await _privateChannelUseCase.execute(
      groupId: groupId,
      content: row.body,
      authorPubkey: pubkeyHex,
      privkeyHex: privkeyHex,
    );
    final afterId = await _latestSelfEventIdInGroup(groupId, pubkeyHex);
    if (afterId != null && afterId != beforeId) return afterId;
    // Fell back if the transport didn't write a row (shouldn't happen).
    return 'pc:$groupId:${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── DM (kind 14, NIP-17) ────────────────────────────────────────────────
  Future<String> _publishDm(
    GanaPendingOutputModel row,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    final convId = row.outputDmConversationId;
    if (convId == null) {
      throw StateError('dm outputType requires outputDmConversationId');
    }
    final conv =
        await _isar.dmConversationModels.filter().idEqualTo(convId).findFirst();
    if (conv == null) {
      throw StateError('DM conversation $convId not found');
    }
    // Same pattern as private channels — `SendDmUseCase` writes the
    // outbound NoteModel synchronously with a deterministic local id.
    // Snapshot before/after and pick the new row.
    final beforeId = await _latestSelfEventIdInDm(conv.id, pubkeyHex);
    final res = await _dmUseCase.call(SendDmParams(
      otherPubkey: conv.otherPubkey,
      content: row.body,
    ));
    return res.fold<Future<String>>(
      (f) async => throw Exception(f.toString()),
      (_) async {
        final afterId = await _latestSelfEventIdInDm(conv.id, pubkeyHex);
        if (afterId != null && afterId != beforeId) return afterId;
        return 'dm:${conv.otherPubkey}:${DateTime.now().millisecondsSinceEpoch}';
      },
    ).then((v) => v);
  }

  // ── Lookups for outputEventId post-send ────────────────────────────────

  Future<String?> _latestSelfEventIdInGroup(
    String groupId,
    String selfPubkey,
  ) async {
    final row = await _isar.noteModels
        .filter()
        .groupIdEqualTo(groupId)
        .authorPubkeyEqualTo(selfPubkey)
        .sortByCreatedDesc()
        .findFirst();
    return row?.eventId;
  }

  Future<String?> _latestSelfEventIdInDm(
    int conversationId,
    String selfPubkey,
  ) async {
    final row = await _isar.noteModels
        .filter()
        .conversationIdEqualTo(conversationId)
        .authorPubkeyEqualTo(selfPubkey)
        .sortByCreatedDesc()
        .findFirst();
    return row?.eventId;
  }

  // ── Run stamping + retry bookkeeping ────────────────────────────────────

  Future<void> _stampRun(String runId, String outputEventId) async {
    final row =
        await _isar.ganaRunModels.filter().runIdEqualTo(runId).findFirst();
    if (row == null) return;
    row.outputEventId = outputEventId;
    await _isar.writeTxn(() async {
      await _isar.ganaRunModels.put(row);
    });
  }

  Future<void> _bumpAttempt(GanaPendingOutputModel row, String error) async {
    row
      ..attempts = row.attempts + 1
      ..lastError = error;
    if (row.attempts >= _maxAttempts) {
      // Give up — mark the run as failed and delete the pending row so we
      // don't loop forever.
      final run = await _isar.ganaRunModels
          .filter()
          .runIdEqualTo(row.runId)
          .findFirst();
      await _isar.writeTxn(() async {
        if (run != null) {
          run
            ..status = GanaRunStatus.failed
            ..error = 'dispatcher gave up: $error';
          await _isar.ganaRunModels.put(run);
        }
        await _isar.ganaPendingOutputModels.delete(row.id);
      });
      return;
    }
    await _isar.writeTxn(() async {
      await _isar.ganaPendingOutputModels.put(row);
    });
  }
}
