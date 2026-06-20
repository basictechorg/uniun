import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/data/models/gana_pending_output_model.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/data/models/manas_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/features/shiv/gana/engine/gana_input_filter.dart';
import 'package:uniun/features/shiv/gana/engine/gana_prompt_builder.dart';
import 'package:uniun/features/shiv/gana/engine/manas_context_loader.dart';
import 'package:uniun/features/shiv/gana/inference/gana_inference_protocol.dart';
import 'package:uuid/uuid.dart';

/// Scheduler + runner for enabled Ganas. Lives in the Gana isolate; owned
/// by `ganaEntryPoint`.
///
/// Reactive triggers fire from `noteModels.watchLazy()` (debounced); interval
/// triggers fire from `Timer.periodic`. Schedule is rebuilt whenever
/// `ganaModels.watchLazy()` emits. Model-swap detection lives on the
/// main-isolate inference server, which cancels its own in-flight chat.
///
/// Single-flight FIFO globally: only one Gana run executes at a time across
/// all reactive + interval triggers. Inflight checks are guarded by
/// [_runMutex].
class GanaEngine {
  GanaEngine({
    required Isar isar,
    required String selfPubkeyHex,
    required SendPort inferencePort,
  })  : _isar = isar,
        _selfPubkeyHex = selfPubkeyHex,
        _inferencePort = inferencePort;

  final Isar _isar;
  final String _selfPubkeyHex;
  final SendPort _inferencePort;

  // ── Schedule state ───────────────────────────────────────────────────────

  /// ganaId → debounce timer for reactive runs. Cancelled and replaced on
  /// every `noteModels.watchLazy()` tick.
  final Map<String, Timer> _reactiveDebounce = {};

  /// ganaId → interval timer.
  final Map<String, Timer> _intervalTimers = {};

  /// Current schedule (loaded on each rebuild).
  List<GanaEntity> _enabledGanas = const [];

  /// Single-flight guard.
  Completer<void>? _runMutex;

  /// Subscriptions to keep alive for the engine's lifetime.
  final List<StreamSubscription<void>> _subs = [];

  /// ganaIds we've already auto-fired this engine lifetime under the
  /// "standalone + one-shot fires on enable" rule. Prevents re-firing on
  /// every schedule rebuild (the Isar watcher emits on any Gana row write,
  /// including run-status updates).
  final Set<String> _firedOnEnable = <String>{};

  static const Duration _reactiveDebounceDelay = Duration(seconds: 3);
  static const Duration _scheduleRebuildDebounce = Duration(milliseconds: 500);

  Future<void> start() async {
    await _rebuildSchedule();

    // 1. Schedule reload on any Gana config change.
    Timer? rebuildDebounce;
    _subs.add(_isar.ganaModels.watchLazy().listen((_) {
      rebuildDebounce?.cancel();
      rebuildDebounce =
          Timer(_scheduleRebuildDebounce, _rebuildSchedule);
    }));

    // 2. Reactive trigger source. We fan a single watcher over all enabled
    //    Ganas — each picks up its own filtered input on tick.
    _subs.add(_isar.noteModels.watchLazy().listen((_) {
      for (final g in _enabledGanas) {
        if (g.triggerReactive && g.inputType != null) {
          _scheduleReactive(g);
        }
      }
    }));

    // Note: model-swap detection lives in the main-isolate inference server
    // (it has direct access to AppSettingsStore via SharedPreferences). The
    // server cancels its own in-flight chat via stopGeneration and replies
    // with `GanaInferenceResponseKind.skippedCancelled`, which the engine
    // logs as `GanaSkipReason.modelSwapped` without advancing the cursor.
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
  }

  // ── Schedule rebuild ─────────────────────────────────────────────────────

  Future<void> _rebuildSchedule() async {
    final rows = await _isar.ganaModels
        .filter()
        .enabledEqualTo(true)
        .findAll();
    _enabledGanas = rows.map((m) => m.toDomain()).toList();

    // Drop interval timers for Ganas that are no longer present/enabled.
    final liveIds = {for (final g in _enabledGanas) g.ganaId};
    final stale = _intervalTimers.keys.where((id) => !liveIds.contains(id)).toList();
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
    // skips it (inputType is null) and there's no interval timer either,
    // so without this kick nothing would ever run it.
    //
    // Guard with `_firedOnEnable` so subsequent rebuilds (triggered by any
    // ganaModels write — including the run status update) don't re-fire it.
    // After a successful one-shot publish the row auto-disables, so it
    // won't show up here again anyway; this guard just covers the window
    // between enable and the run completing.
    for (final g in _enabledGanas) {
      if (g.inputType == null &&
          g.triggerMode == GanaTriggerMode.oneShot &&
          !_firedOnEnable.contains(g.ganaId)) {
        _firedOnEnable.add(g.ganaId);
        debugPrint('[gana-fg] fire-on-enable standalone one-shot '
            'name="${g.name}"');
        // Fire-and-forget — _runIfPossible handles the single-flight mutex.
        unawaited(_runIfPossible(g.ganaId));
      }
    }
    // Drop entries for Ganas that are no longer enabled, so a future
    // disable→enable cycle fires again.
    _firedOnEnable.removeWhere((id) => !liveIds.contains(id));
  }

  // ── Triggers ─────────────────────────────────────────────────────────────

  void _scheduleReactive(GanaEntity g) {
    _reactiveDebounce[g.ganaId]?.cancel();
    _reactiveDebounce[g.ganaId] =
        Timer(_reactiveDebounceDelay, () => _runIfPossible(g.ganaId));
  }

  Future<void> _maybeRunInterval(String ganaId) async {
    // Re-fetch the row each tick so we read the most-recent `lastRunAt`
    // (rebuildSchedule only reloads on config change, not on run completion).
    final row =
        await _isar.ganaModels.filter().ganaIdEqualTo(ganaId).findFirst();
    if (row == null || !row.enabled) return;
    final mins = row.triggerIntervalMinutes;
    if (mins == null || mins <= 0) return;
    final last = row.lastRunAt;
    if (last != null &&
        DateTime.now().difference(last) < Duration(minutes: mins)) {
      return; // not due yet
    }
    await _runIfPossible(ganaId);
  }

  Future<void> _runIfPossible(String ganaId) async {
    if (_runMutex != null) {
      // Another run is in flight; reactive ticks already coalesce via
      // debounce. Interval ticks that arrive here simply skip — the next
      // tick will pick it up.
      return;
    }
    final mutex = _runMutex = Completer<void>();
    try {
      // Refetch — config may have changed since the timer/debounce was set.
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

  // ── One run ──────────────────────────────────────────────────────────────

  Future<void> _runOnce(GanaEntity g) async {
    final startedAt = DateTime.now();
    final runId = const Uuid().v4();
    debugPrint('[gana-fg] ────────────────────────────────────────────');
    debugPrint('[gana-fg] runOnce START name="${g.name}" '
        'runId=${runId.substring(0, 8)} '
        'inputType=${g.inputType?.name ?? "standalone"} '
        'outputType=${g.outputType.name} '
        'mode=${g.triggerMode.name}');

    // Model gates (noActiveModel + modelMismatch) live on the main-isolate
    // server — it has direct access to FlutterGemma + AppSettingsStore.
    // The engine just passes `expectedModelId` and reacts to the response.

    // Fetch input + ancestry + self-output history in parallel.
    final selfOutputs = await _selfOutputs(g.ganaId);
    debugPrint('[gana-fg]   self-outputs guard set: ${selfOutputs.length}');
    final inputs = await GanaInputFilter.fetch(
      isar: _isar,
      gana: g,
      selfPubkeyHex: _selfPubkeyHex,
      selfOutputEventIds: selfOutputs,
    );
    debugPrint('[gana-fg]   input filter: ${inputs.length} note(s)');

    if (g.inputType != null && inputs.isEmpty) {
      debugPrint('[gana-fg]   SKIPPED: noNewInput');
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

    // Knowledge pack.
    final manasNames = await _resolveManasNames(g.manasIds);
    debugPrint('[gana-fg]   Manas: ${manasNames.join(", ")}');
    final knowledge = await ManasContextLoader.merge(
      isar: _isar,
      manasIds: g.manasIds,
      budget: GanaPromptBuilder.defaultMaxTokens ~/ 2,
    );
    debugPrint('[gana-fg]   knowledge packed: ${knowledge.length} note(s)');

    // Assemble prompt.
    final prompt = GanaPromptBuilder.build(
      taskPrompt: g.taskPrompt,
      manasNames: manasNames,
      knowledge: knowledge,
      inputMessagesByOldestFirst: inputs,
      replyAncestry: ancestry,
    );
    debugPrint('[gana-fg]   prompt: ${prompt.length} chars '
        '(~${prompt.length ~/ 4} tokens)');

    // Bridge to main isolate for inference.
    debugPrint('[gana-fg]   inference REQUEST → main isolate '
        '(expectedModelId=${g.desiredModelId ?? "any"})');
    final infStart = DateTime.now();
    final response = await _runInference(
      prompt: prompt,
      expectedModelId: g.desiredModelId,
    );
    debugPrint('[gana-fg]   inference RESPONSE kind=${response.kind.name} '
        'in ${DateTime.now().difference(infStart).inMilliseconds}ms');

    switch (response.kind) {
      case GanaInferenceResponseKind.skippedNoActiveModel:
        await _logRun(
          runId: runId,
          ganaId: g.ganaId,
          startedAt: startedAt,
          status: GanaRunStatus.skipped,
          skipReason: GanaSkipReason.noActiveModel,
        );
        return;
      case GanaInferenceResponseKind.skippedModelMismatch:
        await _logRun(
          runId: runId,
          ganaId: g.ganaId,
          startedAt: startedAt,
          status: GanaRunStatus.skipped,
          skipReason: GanaSkipReason.modelMismatch,
        );
        return;
      case GanaInferenceResponseKind.skippedCancelled:
        await _logRun(
          runId: runId,
          ganaId: g.ganaId,
          startedAt: startedAt,
          status: GanaRunStatus.skipped,
          skipReason: GanaSkipReason.modelSwapped,
        );
        return;
      case GanaInferenceResponseKind.failed:
        await _logRun(
          runId: runId,
          ganaId: g.ganaId,
          startedAt: startedAt,
          status: GanaRunStatus.failed,
          error: response.error,
        );
        return;
      case GanaInferenceResponseKind.ok:
        break; // continue below
    }

    // Already sanitized at LocalLlmRunner.generateOneShot — the single
    // chokepoint every on-device one-shot passes through. Trim only.
    final body = (response.body ?? '').trim();
    if (body.isEmpty || body.toUpperCase() == '<NOOP>') {
      debugPrint('[gana-fg]   SKIPPED: noopReturned '
          '(body=${body.isEmpty ? "empty" : "<NOOP>"})');
      await _logRun(
        runId: runId,
        ganaId: g.ganaId,
        startedAt: startedAt,
        status: GanaRunStatus.skipped,
        skipReason: GanaSkipReason.noopReturned,
      );
      // Advance cursor anyway — we don't want to re-run on the same input
      // when the model has explicitly decided to stay silent.
      await _advanceCursor(g, inputs, lastRunAt: DateTime.now());
      return;
    }
    final preview = body.replaceAll('\n', ' \\n ');
    debugPrint('[gana-fg]   body: "${preview.length > 80 ? '${preview.substring(0, 80)}…' : preview}"');

    // Enqueue for the main-isolate dispatcher to publish.
    debugPrint('[gana-fg]   writing GanaPendingOutputModel '
        '(dispatcher publishes via ${g.outputType.name} path)');
    await _enqueueOutput(
      runId: runId,
      gana: g,
      body: body,
    );

    await _logRun(
      runId: runId,
      ganaId: g.ganaId,
      startedAt: startedAt,
      status: GanaRunStatus.succeeded,
      inputEventIds: inputs.map((n) => n.eventId).toList(),
      // outputEventId is filled in later by the dispatcher.
    );

    await _advanceCursor(g, inputs,
        lastRunAt: DateTime.now(), publishedOutput: true);
    debugPrint('[gana-fg] runOnce END status=succeeded '
        'totalMs=${DateTime.now().difference(startedAt).inMilliseconds}');
  }

  // ── Inference bridge ─────────────────────────────────────────────────────

  Future<GanaInferenceResponse> _runInference({
    required String prompt,
    String? expectedModelId,
  }) async {
    final reply = ReceivePort();
    try {
      _inferencePort.send(GanaInferenceRequest(
        prompt: prompt,
        replyPort: reply.sendPort,
        expectedModelId: expectedModelId,
      ));
      // Wait for exactly one response.
      final res = await reply.first;
      if (res is GanaInferenceResponse) return res;
      return GanaInferenceResponse.failed(
          'Unexpected reply type: ${res.runtimeType}');
    } catch (e) {
      return GanaInferenceResponse.failed(e.toString());
    } finally {
      reply.close();
    }
  }

  // ── Output queue ─────────────────────────────────────────────────────────

  Future<void> _enqueueOutput({
    required String runId,
    required GanaEntity gana,
    required String body,
  }) async {
    final row = GanaPendingOutputModel()
      ..pendingId = const Uuid().v4()
      ..ganaId = gana.ganaId
      ..runId = runId
      ..body = body
      ..outputType = gana.outputType
      ..outputChannelId = gana.outputChannelId
      ..outputGroupId = gana.outputGroupId
      ..outputDmConversationId = gana.outputDmConversationId
      ..createdAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.ganaPendingOutputModels.put(row);
    });
  }

  // ── Run log ──────────────────────────────────────────────────────────────

  Future<void> _logRun({
    required String runId,
    required String ganaId,
    required DateTime startedAt,
    required GanaRunStatus status,
    GanaSkipReason? skipReason,
    List<String> inputEventIds = const [],
    String? error,
  }) async {
    final row = GanaRunModel()
      ..runId = runId
      ..ganaId = ganaId
      ..startedAt = startedAt
      ..status = status
      ..skipReason = skipReason
      ..inputEventIds = inputEventIds
      ..error = error;
    await _isar.writeTxn(() async {
      await _isar.ganaRunModels.put(row);
    });
  }

  // ── Cursor advance ───────────────────────────────────────────────────────

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
      final last = inputs.last; // oldest-first → last is the newest
      row
        ..lastProcessedEventId = last.eventId
        ..lastProcessedCreated = last.created;
    }
    row.lastRunAt = lastRunAt;
    // One-shot Ganas auto-disable after a real publish. `publishedOutput`
    // is true only when the model actually produced a non-NOOP body and
    // we wrote the pending row — NOOP runs don't burn the one-shot.
    if (publishedOutput && row.triggerMode == GanaTriggerMode.recurring) {
      // Recurring stays enabled — no change.
    } else if (publishedOutput &&
        row.triggerMode == GanaTriggerMode.oneShot) {
      row.enabled = false;
    }
    await _isar.writeTxn(() async {
      await _isar.ganaModels.put(row);
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
