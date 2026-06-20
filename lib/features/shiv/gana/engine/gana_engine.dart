import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/local_llm_runner.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/domain/usecases/create_channel_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_channel_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';
import 'package:uniun/features/shiv/gana/engine/gana_input_filter.dart';
import 'package:uniun/features/shiv/gana/engine/gana_prompt_builder.dart';
import 'package:uniun/features/shiv/gana/engine/manas_context_loader.dart';
import 'package:uuid/uuid.dart';

/// Scheduler + runner for enabled Ganas, running in the main isolate.
///
/// Architecture decision (2026-06-20): the engine no longer runs in its own
/// isolate. Its hot path is event-driven (`Isar.watchLazy`, `Timer.periodic`)
/// + FFI inference (native-threaded) — no pure-Dart CPU work that would
/// justify the cost of cross-isolate plumbing. Living in the main isolate
/// gives us:
///
///   • Direct calls to `AIModelRunner.generateOneShot` (which routes through
///     `LocalInferenceQueue.runLow` so Shiv chat (`runHigh`) preempts).
///   • Direct calls to publish use cases (NIP-17 DM gift-wrap, NIP-29 MLS
///     private channels) without going through a pending-table dispatcher.
///   • Direct access to `EmbeddingService` for Manas vector retrieval.
///
/// Trade-off: prompt building + Isar reads + result handling run on the main
/// isolate. Total Dart-thread work per Gana run: ~30-50ms spread across the
/// generation's wall-clock window (200+ seconds). Negligible at 60 Hz.
///
/// Single-flight FIFO globally: only one Gana run executes at a time across
/// all reactive + interval triggers. Guarded by [_runMutex].
///
/// **Background path:** the WorkManager dispatcher (`gana_workmanager.dart`)
/// stays as-is. It runs in its OS-dispatched isolate when the app is
/// killed/backgrounded; the engine here is foreground only.
@lazySingleton
class GanaEngine {
  GanaEngine(
    this._isar,
    this._runner,
    this._settings,
    this._userRepo,
    this._publishNote,
    this._channelMessage,
    this._dm,
    this._privateChannel,
    this._embedAndStore,
  );

  final Isar _isar;
  final AIModelRunner _runner;
  final AppSettingsStore _settings;
  final UserRepository _userRepo;
  final PublishNoteUseCase _publishNote;
  final CreateChannelMessageUseCase _channelMessage;
  final SendDmUseCase _dm;
  final SendPrivateChannelMessageUsecase _privateChannel;
  final EmbedAndStoreNoteUseCase _embedAndStore;

  // ── Schedule state ─────────────────────────────────────────────────────

  /// ganaId → debounce timer for reactive runs. Cancelled and replaced on
  /// every `noteModels.watchLazy()` tick.
  final Map<String, Timer> _reactiveDebounce = {};

  /// ganaId → interval timer.
  final Map<String, Timer> _intervalTimers = {};

  /// Current schedule (loaded on each rebuild).
  List<GanaEntity> _enabledGanas = const [];

  /// Single-flight guard. One Gana run at a time, app-wide.
  Completer<void>? _runMutex;

  /// Subscriptions to keep alive for the engine's lifetime.
  final List<StreamSubscription<void>> _subs = [];

  /// ganaIds we've already auto-fired this engine lifetime under the
  /// "standalone + one-shot fires on enable" rule. Prevents re-firing on
  /// every schedule rebuild (the Isar watcher emits on any Gana row write,
  /// including run-status updates).
  final Set<String> _firedOnEnable = <String>{};

  bool _started = false;

  static const Duration _reactiveDebounceDelay = Duration(seconds: 3);
  static const Duration _scheduleRebuildDebounce = Duration(milliseconds: 500);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _rebuildSchedule();

    // Schedule reload on any Gana config change.
    Timer? rebuildDebounce;
    _subs.add(_isar.ganaModels.watchLazy().listen((_) {
      rebuildDebounce?.cancel();
      rebuildDebounce =
          Timer(_scheduleRebuildDebounce, _rebuildSchedule);
    }));

    // Reactive trigger source. Single watcher; each enabled Gana picks up
    // its own filtered input on tick.
    _subs.add(_isar.noteModels.watchLazy().listen((_) {
      for (final g in _enabledGanas) {
        if (g.triggerReactive && g.inputType != null) {
          _scheduleReactive(g);
        }
      }
    }));

    debugPrint('GanaEngine started (main isolate)');
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final t in _reactiveDebounce.values) {
      t.cancel();
    }
    _reactiveDebounce.clear();
    for (final t in _intervalTimers.values) {
      t.cancel();
    }
    _intervalTimers.clear();
    _started = false;
  }

  // ── Schedule rebuild ───────────────────────────────────────────────────

  Future<void> _rebuildSchedule() async {
    final rows =
        await _isar.ganaModels.filter().enabledEqualTo(true).findAll();
    _enabledGanas = rows.map((m) => m.toDomain()).toList();

    final liveIds = {for (final g in _enabledGanas) g.ganaId};
    final stale =
        _intervalTimers.keys.where((id) => !liveIds.contains(id)).toList();
    for (final id in stale) {
      _intervalTimers.remove(id)?.cancel();
    }

    // (Re)install interval timers — cancel-and-replace is fine because
    // interval minutes are anchored on `lastRunAt`, so we don't lose the
    // schedule across a reload.
    for (final g in _enabledGanas) {
      final mins = g.triggerIntervalMinutes;
      if (mins == null || mins <= 0) {
        _intervalTimers.remove(g.ganaId)?.cancel();
        continue;
      }
      _intervalTimers.remove(g.ganaId)?.cancel();
      _intervalTimers[g.ganaId] = Timer.periodic(
        Duration(minutes: mins),
        (_) => _maybeRunInterval(g.ganaId),
      );
    }

    debugPrint('GanaEngine: schedule rebuilt with '
        '${_enabledGanas.length} enabled Gana(s)');

    // Standalone + one-shot fires immediately on enable. Reactive watcher
    // skips it (inputType is null) and there's no interval timer either.
    // `_firedOnEnable` guards against re-firing on every rebuild.
    for (final g in _enabledGanas) {
      if (g.inputType == null &&
          g.triggerMode == GanaTriggerMode.oneShot &&
          !_firedOnEnable.contains(g.ganaId)) {
        _firedOnEnable.add(g.ganaId);
        debugPrint('[gana] fire-on-enable standalone one-shot '
            'name="${g.name}"');
        unawaited(_runIfPossible(g.ganaId));
      }
    }
    _firedOnEnable.removeWhere((id) => !liveIds.contains(id));
  }

  // ── Triggers ───────────────────────────────────────────────────────────

  void _scheduleReactive(GanaEntity g) {
    _reactiveDebounce[g.ganaId]?.cancel();
    _reactiveDebounce[g.ganaId] =
        Timer(_reactiveDebounceDelay, () => _runIfPossible(g.ganaId));
  }

  Future<void> _maybeRunInterval(String ganaId) async {
    final row =
        await _isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
    if (row == null || !row.enabled) return;
    final mins = row.triggerIntervalMinutes;
    if (mins == null || mins <= 0) return;
    final last = row.lastRunAt;
    if (last != null &&
        DateTime.now().difference(last) < Duration(minutes: mins)) {
      return;
    }
    await _runIfPossible(ganaId);
  }

  Future<void> _runIfPossible(String ganaId) async {
    if (_runMutex != null) return; // single-flight
    final mutex = _runMutex = Completer<void>();
    try {
      final row =
          await _isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
      if (row == null || !row.enabled) return;
      await _runOnce(row.toDomain());
    } catch (e, st) {
      debugPrint('GanaEngine: unexpected error in _runOnce: $e\n$st');
    } finally {
      _runMutex = null;
      mutex.complete();
    }
  }

  // ── One run ────────────────────────────────────────────────────────────

  Future<void> _runOnce(GanaEntity g) async {
    final startedAt = DateTime.now();
    final runId = const Uuid().v4();
    debugPrint('[gana] ────────────────────────────────────────────');
    debugPrint('[gana] runOnce START name="${g.name}" '
        'runId=${runId.substring(0, 8)} '
        'inputType=${g.inputType?.name ?? "standalone"} '
        'outputType=${g.outputType.name} '
        'mode=${g.triggerMode.name}');

    // Model gates — done inline now that we're in the main isolate.
    if (!FlutterGemma.hasActiveModel()) {
      debugPrint('[gana]   SKIPPED: noActiveModel');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.noActiveModel,
      );
      return;
    }
    final activeIdName = _settings.activeModelId?.name;
    if (g.desiredModelId != null &&
        activeIdName != null &&
        g.desiredModelId != activeIdName) {
      debugPrint('[gana]   SKIPPED: modelMismatch '
          '(desired=${g.desiredModelId} active=$activeIdName)');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.modelMismatch,
      );
      return;
    }

    // Fetch input + self-output history.
    final selfOutputs = await _selfOutputs(g.ganaId);
    debugPrint('[gana]   self-outputs guard set: ${selfOutputs.length}');

    // Recurring cap — count this run BEFORE doing inference work so we
    // bail early. One-shot Ganas auto-disable on first publish anyway,
    // so the cap is recurring-only.
    if (g.triggerMode == GanaTriggerMode.recurring &&
        g.maxOutputs != null &&
        selfOutputs.length >= g.maxOutputs!) {
      debugPrint('[gana]   SKIPPED: maxOutputsReached '
          '(${selfOutputs.length}/${g.maxOutputs}) — auto-disabling');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.maxOutputsReached,
      );
      await _disable(g.ganaId);
      return;
    }

    final keys = await _userRepo.getActiveKeysHex();
    if (keys == null) {
      debugPrint('[gana]   SKIPPED: no active user');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.noActiveModel,
        error: 'no active user',
      );
      return;
    }

    final inputs = await GanaInputFilter.fetch(
      isar: _isar,
      gana: g,
      selfPubkeyHex: keys.pubkeyHex,
      selfOutputEventIds: selfOutputs,
    );
    debugPrint('[gana]   input filter: ${inputs.length} note(s)');

    if (g.inputType != null && inputs.isEmpty) {
      debugPrint('[gana]   SKIPPED: noNewInput');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.noNewInput,
      );
      return;
    }

    // Reply ancestry per input.
    final ancestry = <String, List<NoteModel>>{};
    for (final n in inputs) {
      if (n.replyToEventId != null) {
        ancestry[n.eventId] =
            await GanaInputFilter.ancestry(isar: _isar, note: n);
      }
    }

    // Knowledge pack. When input is present we use it as the relevance
    // query; otherwise fall back to newest-first packing.
    final manasNames = await _resolveManasNames(g.manasIds);
    debugPrint('[gana]   Manas: ${manasNames.join(", ")}');
    final queryText = inputs.isEmpty
        ? null
        : inputs.map((n) => n.content).join('\n').trim();
    final knowledge = await ManasContextLoader.merge(
      isar: _isar,
      manasIds: g.manasIds,
      budget: GanaPromptBuilder.defaultMaxTokens ~/ 2,
      relevanceQuery: queryText,
    );
    debugPrint('[gana]   knowledge packed: ${knowledge.length} note(s)'
        '${queryText == null ? "" : " (by-relevance)"}');

    // Assemble prompt.
    final prompt = GanaPromptBuilder.build(
      taskPrompt: g.taskPrompt,
      manasNames: manasNames,
      knowledge: knowledge,
      inputMessagesByOldestFirst: inputs,
      replyAncestry: ancestry,
    );
    debugPrint('[gana]   prompt: ${prompt.length} chars '
        '(~${prompt.length ~/ 4} tokens)');

    // Inference — direct call, no SendPort.
    final modelBefore = _settings.activeModelId?.name;
    debugPrint('[gana]   inference REQUEST (active=$modelBefore)');
    final infStart = DateTime.now();
    String? text;
    String? error;
    try {
      text = await _runner.generateOneShot(prompt);
    } catch (e) {
      error = e.toString();
    }
    final infMs = DateTime.now().difference(infStart).inMilliseconds;

    if (error != null) {
      debugPrint('[gana]   inference FAILED in ${infMs}ms: $error');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.failed,
        error: error,
      );
      return;
    }
    if (text == null) {
      // Runner returned null → preempted (chat cut in) or model swapped.
      final modelAfter = _settings.activeModelId?.name;
      final swapped = modelAfter != modelBefore;
      debugPrint('[gana]   inference CANCELLED in ${infMs}ms '
          '(${swapped ? "modelSwapped" : "preempted"})');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.modelSwapped,
      );
      return;
    }

    // Already sanitized at AIModelRunner.generateOneShot (the chokepoint).
    final body = text.trim();
    debugPrint('[gana]   inference OK in ${infMs}ms (${body.length} chars)');
    if (body.isEmpty ||
        body.toUpperCase() == GanaPromptBuilder.noopSentinel) {
      debugPrint('[gana]   SKIPPED: noopReturned');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.noopReturned,
      );
      await _advanceCursor(g, inputs, lastRunAt: DateTime.now());
      return;
    }
    final preview = body.replaceAll('\n', ' \\n ');
    debugPrint('[gana]   body: "'
        '${preview.length > 80 ? '${preview.substring(0, 80)}…' : preview}"');

    // Publish — engine calls the use case directly. No pending table.
    String? outputEventId;
    try {
      outputEventId = await _publish(
        g,
        body,
        privkeyHex: keys.privkeyHex,
        pubkeyHex: keys.pubkeyHex,
      );
    } catch (e, st) {
      debugPrint('[gana]   PUBLISH FAILED: $e\n$st');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.failed,
        error: 'publish: $e',
      );
      return;
    }

    debugPrint('[gana]   PUBLISHED outputEventId='
        '${outputEventId.length > 12 ? outputEventId.substring(0, 12) : outputEventId}');
    await _logRun(
      runId: runId,
      ganaId: g.ganaId,
      startedAt: startedAt,
      status: GanaRunStatus.succeeded,
      inputEventIds: inputs.map((n) => n.eventId).toList(),
      outputEventId: outputEventId,
    );
    await _advanceCursor(g, inputs,
        lastRunAt: DateTime.now(), publishedOutput: true);
    debugPrint('[gana] runOnce END status=succeeded '
        'totalMs=${DateTime.now().difference(startedAt).inMilliseconds}');
  }

  // ── Publish — direct calls, no pending table ───────────────────────────

  Future<String> _publish(
    GanaEntity g,
    String body, {
    required String privkeyHex,
    required String pubkeyHex,
  }) async {
    switch (g.outputType) {
      case GanaOutputType.feed:
        return await _publishFeed(body, privkeyHex, pubkeyHex);
      case GanaOutputType.channel:
        return await _publishChannel(g.outputChannelId, body, privkeyHex);
      case GanaOutputType.privateChannel:
        return await _publishPrivateChannel(
            g.outputGroupId, body, privkeyHex, pubkeyHex);
      case GanaOutputType.dm:
        return await _publishDm(
            g.outputDmConversationId, body, pubkeyHex);
    }
  }

  Future<String> _publishFeed(
    String body,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    final event = signNostrEvent(
      content: body,
      tags: const <List<String>>[],
      privkeyHex: privkeyHex,
    );
    final entity = noteEntityFromEvent(
      event: event,
      pubkeyHex: pubkeyHex,
      eTagRefs: const [],
      tTags: const [],
    );
    final res = await _publishNote.call(entity);
    return res.fold(
      (f) => throw Exception(f.toString()),
      (note) {
        // Feed the Gana's own note into the RAG pipeline the same way
        // Brahma feeds user-typed notes. Without this, the note shows up
        // in Vishnu but is invisible to vector search — so future Ganas
        // (and Shiv chat) can't surface it as context.
        unawaited(_embedAndStore.call((note.id, note.content)));
        return note.id;
      },
    );
  }

  Future<String> _publishChannel(
    String? channelId,
    String body,
    String privkeyHex,
  ) async {
    if (channelId == null) {
      throw StateError('channel outputType requires outputChannelId');
    }
    final res = await _channelMessage.call(CreateChannelMessageInput(
      channelId: channelId,
      content: body,
      privateKey: privkeyHex,
    ));
    return res.fold(
      (f) => throw Exception(f.toString()),
      (note) => note.id,
    );
  }

  Future<String> _publishPrivateChannel(
    String? groupId,
    String body,
    String privkeyHex,
    String pubkeyHex,
  ) async {
    if (groupId == null) {
      throw StateError('privateChannel outputType requires outputGroupId');
    }
    // `execute` returns void; the transport writes a NoteModel synchronously.
    // Snapshot before/after to recover the eventId.
    final before = await _latestSelfEventIdInGroup(groupId, pubkeyHex);
    await _privateChannel.execute(
      groupId: groupId,
      content: body,
      authorPubkey: pubkeyHex,
      privkeyHex: privkeyHex,
    );
    final after = await _latestSelfEventIdInGroup(groupId, pubkeyHex);
    if (after != null && after != before) return after;
    return 'pc:$groupId:${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _publishDm(
    int? conversationId,
    String body,
    String pubkeyHex,
  ) async {
    if (conversationId == null) {
      throw StateError('dm outputType requires outputDmConversationId');
    }
    final conv = await _isar.dmConversationModels
        .filter()
        .idEqualTo(conversationId)
        .findFirst();
    if (conv == null) {
      throw StateError('DM conversation $conversationId not found');
    }
    final before = await _latestSelfEventIdInDm(conv.id, pubkeyHex);
    final res = await _dm.call(SendDmParams(
      otherPubkey: conv.otherPubkey,
      content: body,
    ));
    return res.fold<Future<String>>(
      (f) async => throw Exception(f.toString()),
      (_) async {
        final after = await _latestSelfEventIdInDm(conv.id, pubkeyHex);
        if (after != null && after != before) return after;
        return 'dm:${conv.otherPubkey}:${DateTime.now().millisecondsSinceEpoch}';
      },
    );
  }

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

  // ── Run log + cursor advance ───────────────────────────────────────────

  Future<void> _logRun({
    required String runId,
    required String ganaId,
    required DateTime startedAt,
    required GanaRunStatus status,
    GanaSkipReason? skipReason,
    List<String> inputEventIds = const [],
    String? outputEventId,
    String? error,
  }) async {
    final row = GanaRunModel()
      ..runId = runId
      ..ganaId = ganaId
      ..startedAt = startedAt
      ..status = status
      ..skipReason = skipReason
      ..inputEventIds = inputEventIds
      ..outputEventId = outputEventId
      ..error = error;
    await _isar.writeTxn(() async {
      await _isar.ganaRunModels.put(row);
    });
  }

  Future<void> _advanceCursor(
    GanaEntity g,
    List<NoteModel> inputs, {
    required DateTime lastRunAt,
    bool publishedOutput = false,
  }) async {
    final row =
        await _isar.ganaModels.filter().ganaIdEqualTo(g.ganaId).findFirst();
    if (row == null) return;
    if (inputs.isNotEmpty) {
      final last = inputs.last; // oldest-first → last is newest
      row
        ..lastProcessedEventId = last.eventId
        ..lastProcessedCreated = last.created;
    }
    row.lastRunAt = lastRunAt;
    // One-shot Ganas auto-disable after a real publish. NOOP runs don't
    // burn the one-shot; the user can retry.
    if (publishedOutput && row.triggerMode == GanaTriggerMode.oneShot) {
      row.enabled = false;
    }
    await _isar.writeTxn(() async {
      await _isar.ganaModels.put(row);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _disable(String ganaId) async {
    final row =
        await _isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
    if (row == null) return;
    row.enabled = false;
    await _isar.writeTxn(() async {
      await _isar.ganaModels.put(row);
    });
  }

  Future<Set<String>> _selfOutputs(String ganaId) async {
    final ids = await _isar.ganaRunModels
        .filter()
        .ganaIdEqualTo(ganaId)
        .outputEventIdIsNotNull()
        .outputEventIdProperty()
        .findAll();
    return ids.cast<String>().toSet();
  }

  Future<List<String>> _resolveManasNames(List<String> manasIds) async {
    if (manasIds.isEmpty) return const [];
    final names = <String>[];
    for (final id in manasIds) {
      final row =
          await _isar.manasModels.filter().manasIdEqualTo(id).findFirst();
      if (row != null) names.add(row.name);
    }
    return names;
  }
}

