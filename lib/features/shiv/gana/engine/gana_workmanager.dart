import 'package:flutter/widgets.dart';
import 'package:flutter_gemma/flutter_gemma.dart' hide Message;
import 'package:flutter_gemma/core/message.dart' as gemma_msg;
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr/nostr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uniun/core/utils/llm_text_sanitizer.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/isar_schemas.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/features/shiv/gana/engine/gana_prompt_builder.dart';
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/generation/gana_run.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

/// Background task name. Must match `BGTaskSchedulerPermittedIdentifiers`
/// in `ios/Runner/Info.plist`. Android only requires the constant to be
/// stable across schedules.
const String kGanaBackgroundTickTask = 'in.uniun.app.gana.tick';

/// Hard wall-clock cap per background run. Qwen3 0.6B benchmark on
/// arm64-v8a: ~9s engine init + ~4s first token + ~0.3s/token decode.
/// 90s budget allows ~250 tokens of output with safety margin.
const Duration kBackgroundRunBudget = Duration(seconds: 90);

/// Battery-fairness clamp: regardless of a Gana's `triggerIntervalMinutes`,
/// the engine never considers it "due" in background more often than this.
/// A 5-min Gana run in foreground will be skipped in bg until 30 min have
/// elapsed since `lastRunAt`.
const Duration kBackgroundMinInterval = Duration(minutes: 30);

/// How long after the app is backgrounded before the OS attempts to fire
/// the first tick. Short delay = quicker pickup; the OS still defers
/// further based on Doze, App Standby Bucket, network + battery
/// constraints, so this is a floor, not a guarantee. Production default
/// is 1 minute; raise to 15-30 min if battery profiling shows the bg
/// tick is too eager.
const Duration kBackgroundInitialDelay = Duration(minutes: 1);

/// Max tokens generated per background run. Bumped from 256 → 1024
/// because Qwen3 produces a <think>...</think> reasoning block before
/// the answer; if maxTokens runs out mid-thought, LlmTextSanitizer
/// returns empty and the run skips. 1024 gives the model room to
/// finish reasoning AND emit a 1-3 sentence answer.
const int kBackgroundMaxTokens = 1024;

/// One Gana per tick. Loading flutter_gemma costs ~9s; doing two would
/// blow the budget. Foreground catches up on the next app open.
const int kBackgroundMaxGanasPerTick = 1;

/// WorkManager dispatcher — top-level function MUST be top-level (not a
/// class method) because the plugin tears off its reference.
///
/// ## What it DOES
///
/// 1. Boots BackgroundIsolateBinaryMessenger so plugin channels work.
/// 2. Opens its own Isar handle at the shared DB path.
/// 3. Initializes flutter_gemma 1.0.0 with the same engine list as
///    `main.dart`. Verified PASS by
///    `integration_test/flutter_gemma_bg_isolate_test.dart` (Qwen3 0.6B
///    fresh-load on Android arm64 in 9.2s).
/// 4. Picks ONE due interval Gana (battery-clamped to ≥30 min).
/// 5. Runs the full engine flow: input filter → reply ancestry →
///    Manas context pack → prompt build → openChat → inference →
///    publish (feed/channel in-isolate; DM/private skipped — see below) →
///    log GanaRunModel → advance cursor.
/// 6. Closes Isar, returns.
///
/// ## What it does NOT do
///
/// - Reactive triggers. The gateway isolate is NOT running here, so new
///   notes don't arrive while the app is killed. Only interval Ganas
///   fire in the background.
/// - DM + private-channel publishing in bg. Those kinds need
///   main-isolate-only native plugins (NIP-17 gift-wrap / NIP-29 MLS).
///   The bg tick logs a skip; the foreground engine reactively picks the
///   same input up on next app open. One-shot DM/PC Ganas with no
///   reactive trigger therefore won't fire from bg — known limitation.
/// Single log tag prefix so it's easy to filter in `adb logcat`:
///
///   adb logcat | grep '\[gana\]'
///
/// Every step prints a timestamp delta from tick start so you can see
/// where time goes (model init, prompt build, generation, publish).
const String _logTag = '[gana]';
DateTime? _tickStart;

void _log(String msg) {
  final t = _tickStart;
  if (t == null) {
    debugPrint('$_logTag $msg');
    return;
  }
  final delta = DateTime.now().difference(t).inMilliseconds;
  debugPrint('$_logTag +${delta.toString().padLeft(6)}ms $msg');
}

@pragma('vm:entry-point')
void ganaWorkManagerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kGanaBackgroundTickTask) {
      debugPrint('$_logTag ignored unknown task: $taskName');
      return true;
    }

    _tickStart = DateTime.now();
    _log('═══════════════════════════════════════════════════════════');
    _log('bg tick START (budget=${kBackgroundRunBudget.inSeconds}s)');

    WidgetsFlutterBinding.ensureInitialized();
    final budgetEnd = DateTime.now().add(kBackgroundRunBudget);

    Isar? isar;
    try {
      // 1. Open Isar at the shared path.
      _log('step 1: opening Isar at shared DB path');
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open(
        isarSchemas,
        directory: dir.path,
        name: Isar.defaultName,
      );
      _log('step 1: Isar opened');

      // 2. Resolve self keys from inputData (passed by
      //    GanaWorkmanagerBootstrap.scheduleBackground). Without pubkey we can't
      //    apply the self-loop guard; without privkey we can't sign
      //    kind-1 / kind-42 outputs — bail.
      _log('step 2: reading inputData (selfPubkeyHex + privkeyHex)');
      final selfPubkeyHex = inputData?['selfPubkeyHex'] as String?;
      final privkeyHex = inputData?['privkeyHex'] as String?;
      if (selfPubkeyHex == null || selfPubkeyHex.isEmpty) {
        _log('step 2: ABORT — no selfPubkeyHex in inputData');
        await isar.close();
        return true;
      }
      _log('step 2: selfPubkey=${_shortHex(selfPubkeyHex)} '
          'privkey=${privkeyHex == null ? "missing" : "present"}');

      // 3. Pick the next due Gana. We sort by lastRunAt ascending so the
      //    Gana that's been waiting longest runs first.
      _log('step 3: scanning enabled Ganas');
      final candidates = await isar.ganaModels
          .filter()
          .enabledEqualTo(true)
          .findAll();
      _log('step 3: ${candidates.length} enabled Gana(s) found');
      candidates.sort((a, b) {
        final ta = a.lastRunAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.lastRunAt?.millisecondsSinceEpoch ?? 0;
        return ta.compareTo(tb);
      });

      final due = <GanaModel>[];
      for (final g in candidates) {
        final mins = g.triggerIntervalMinutes;
        if (mins == null || mins <= 0) {
          _log('step 3:   "${g.name}" → skip (no interval set)');
          continue;
        }
        final effective = Duration(minutes: mins) < kBackgroundMinInterval
            ? kBackgroundMinInterval
            : Duration(minutes: mins);
        final last = g.lastRunAt;
        if (last != null && DateTime.now().difference(last) < effective) {
          final secsLeft = (effective - DateTime.now().difference(last))
              .inSeconds;
          _log('step 3:   "${g.name}" → skip '
              '(next due in ${secsLeft}s)');
          continue;
        }
        _log('step 3:   "${g.name}" → DUE (last run '
            '${last == null ? "never" : "${DateTime.now().difference(last).inMinutes}m ago"})');
        due.add(g);
        if (due.length >= kBackgroundMaxGanasPerTick) break;
      }

      if (due.isEmpty) {
        _log('step 3: nothing due, exiting cleanly');
        await isar.close();
        return true;
      }

      // 4. Initialize flutter_gemma (same engine list as main.dart).
      _log('step 4: FlutterGemma.initialize '
          '(LiteRtLm + MediaPipe + LiteRtEmbedder)');
      final initStart = DateTime.now();
      try {
        await FlutterGemma.initialize(
          inferenceEngines: const [
            LiteRtLmEngine(),
            MediaPipeEngine(),
          ],
          embeddingBackends: const [
            LiteRtEmbeddingBackend(),
          ],
        );
      } catch (e, st) {
        _log('step 4: ABORT — FlutterGemma.initialize threw: $e');
        debugPrint('$_logTag stack: $st');
        await isar.close();
        return false;
      }
      _log('step 4: initialized in '
          '${DateTime.now().difference(initStart).inMilliseconds}ms');

      _log('step 4b: checking hasActiveModel()');
      if (!FlutterGemma.hasActiveModel()) {
        _log('step 4b: ABORT — no active model installed');
        await isar.close();
        return true;
      }
      _log('step 4b: active model present');

      // 5. Run the chosen Gana.
      _log('step 5: running ${due.length} Gana(s)');
      for (final ganaRow in due) {
        if (DateTime.now().isAfter(budgetEnd)) {
          _log('step 5: budget exhausted before next run');
          break;
        }
        await _runOneGana(
          isar: isar,
          ganaRow: ganaRow,
          selfPubkeyHex: selfPubkeyHex,
          privkeyHex: privkeyHex,
          budgetEnd: budgetEnd,
        );
      }

      await isar.close();
      _log('bg tick END ok');
      return true;
    } catch (e, st) {
      _log('bg tick FAILED: $e');
      debugPrint('$_logTag stack: $st');
      try {
        await isar?.close();
      } catch (_) {
        // already closed or never opened
      }
      return false; // workmanager retries on next schedule
    }
  });
}

Future<void> _runOneGana({
  required Isar isar,
  required GanaModel ganaRow,
  required String selfPubkeyHex,
  required String? privkeyHex,
  required DateTime budgetEnd,
}) async {
  final gana = ganaRow.toDomain();
  final runId = const Uuid().v4();
  final startedAt = DateTime.now();
  _log('───────────────────────────────────────────────────────');
  _log('runOneGana START name="${gana.name}" runId=${runId.substring(0, 8)}');
  _log('  manases=${gana.manasIds.length} '
      'inputType=${gana.inputType?.name ?? "standalone"} '
      'outputType=${gana.outputType.name} '
      'mode=${gana.triggerMode.name}');

  // Self-output guard set.
  final selfOutputs = await ganaSelfOutputs(isar, gana.ganaId);
  _log('  self-outputs: ${selfOutputs.length} eventIds');

  // Input → ancestry → knowledge (newest-first in bg) → prompt. Shared with the
  // foreground engine via [prepareGanaRun]; bg injects the no-DI newest-first
  // Manas pool (ignores the relevance query).
  final prepared = await prepareGanaRun(
    isar: isar,
    gana: gana,
    selfPubkeyHex: selfPubkeyHex,
    selfOutputs: selfOutputs,
    loadKnowledge: (_) => ManasContextLoader.packNewest(
      isar: isar,
      manasIds: gana.manasIds,
      budget: GanaPromptBuilder.defaultMaxTokens ~/ 2,
    ),
  );
  if (prepared == null) {
    _log('  SKIPPED: noNewInput (cursor caught up, nothing to do)');
    await _writeRun(
      isar: isar,
      runId: runId,
      ganaId: gana.ganaId,
      startedAt: startedAt,
      status: GanaRunStatus.skipped,
      skipReason: GanaSkipReason.noNewInput,
    );
    return;
  }
  final inputs = prepared.inputs;
  final prompt = prepared.prompt;
  _log('  input: ${inputs.length} note(s); Manas: '
      '${prepared.manasNames.join(", ")}; prompt: ${prompt.length} chars '
      '(~${prompt.length ~/ 4} tokens)');

  if (DateTime.now().isAfter(budgetEnd)) {
    _log('  ABORT: budget exhausted before inference');
    return;
  }

  // Inference. Throwaway chat — matches the foreground generateOneShot
  // pattern in AIModelRunner.
  _log('  generation START (maxTokens=$kBackgroundMaxTokens)');
  String? body;
  final infStart = DateTime.now();
  var tokenCount = 0;
  DateTime? firstTokenAt;
  try {
    _log('  opening model handle (GPU preferred)');
    // Prefer GPU, fall back to CPU on engine-creation failure — mirrors the
    // foreground AIModelRunner so a device without a usable GPU delegate still
    // runs the bg tick instead of failing the whole run.
    InferenceModel model;
    try {
      model = await FlutterGemma.getActiveModel(
        maxTokens: kBackgroundMaxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
    } catch (e) {
      _log('  GPU open failed ($e) — retrying on CPU');
      model = await FlutterGemma.getActiveModel(
        maxTokens: kBackgroundMaxTokens,
        preferredBackend: PreferredBackend.cpu,
      );
    }
    _log('  opening chat session');
    final chat = await model.openChat(
      temperature: 0.6,
      topK: 20,
      tokenBuffer: 128,
    );
    _log('  feeding prompt');
    try {
      await chat.addQueryChunk(gemma_msg.Message.text(text: prompt));
      _log('  streaming tokens...');
      final buf = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse && response.token.isNotEmpty) {
          firstTokenAt ??= DateTime.now();
          if (tokenCount == 0) {
            _log('  first token in '
                '${firstTokenAt.difference(infStart).inMilliseconds}ms '
                '(prefill done)');
          }
          buf.write(response.token);
          tokenCount += 1;
          // Periodic heartbeat so a runaway generation is visible in logs.
          if (tokenCount % 32 == 0) {
            _log('  ... $tokenCount tokens so far');
          }
        }
        if (DateTime.now().isAfter(budgetEnd)) {
          _log('  BUDGET EXHAUSTED mid-stream after $tokenCount tokens; '
              'stopGeneration()');
          try {
            await chat.stopGeneration();
          } catch (_) {
            // best effort; engine teardown handles partial state
          }
          break;
        }
      }
      body = buf.toString();
      _log('  stream END: $tokenCount tokens, ${body.length} chars');
    } finally {
      try {
        await chat.close();
      } catch (_) {
        // session may be already closing — ignore
      }
    }
  } catch (e, st) {
    _log('  FAILED: $e');
    debugPrint('$_logTag stack: $st');
    await _writeRun(
      isar: isar,
      runId: runId,
      ganaId: gana.ganaId,
      startedAt: startedAt,
      status: GanaRunStatus.failed,
      error: e.toString(),
    );
    return;
  }
  final totalMs = DateTime.now().difference(infStart).inMilliseconds;
  final prefillMs =
      firstTokenAt?.difference(infStart).inMilliseconds ?? totalMs;
  final decodeMs = totalMs - prefillMs;
  final tps = tokenCount > 0 && decodeMs > 0
      ? (tokenCount * 1000 / decodeMs).toStringAsFixed(1)
      : '-';
  _log('  generation END: total=${totalMs}ms '
      'prefill=${prefillMs}ms decode=${decodeMs}ms '
      'tokens=$tokenCount ($tps tok/s)');

  // Same chokepoint discipline as the foreground engine: every on-device
  // LLM output runs through LlmTextSanitizer.clean before being persisted
  // or published. Strips <think>...</think> reasoning blocks, tool-call
  // envelopes, and decodes GPT-2 byte-mojibake (emoji).
  // If the model was cut off mid-thought (open <think> with no close),
  // the sanitizer returns '' and we treat it as a NOOP skip.
  final trimmed = LlmTextSanitizer.clean(body);
  if (isGanaNoop(trimmed)) {
    _log('  SKIPPED: noopReturned '
        '(body=${trimmed.isEmpty ? "empty/think-only" : "<NOOP>"})');
    await _writeRun(
      isar: isar,
      runId: runId,
      ganaId: gana.ganaId,
      startedAt: startedAt,
      status: GanaRunStatus.skipped,
      skipReason: GanaSkipReason.noopReturned,
    );
    // Advance cursor anyway — model decided to stay silent on this input.
    await _advanceCursor(isar: isar, ganaRow: ganaRow, inputs: inputs);
    return;
  }
  _log('  body preview: "${_previewBody(trimmed)}"');

  // Route by output type:
  //   - feed (kind 1) / channel (kind 42): sign locally + write to
  //     EventQueueModel. The gateway isolate's watcher picks it up and
  //     broadcasts. ZERO main-isolate hops.
  //   - dm (NIP-17) / privateChannel (NIP-29 MLS): native plugins are
  //     main-isolate-only. Skipped in bg; foreground engine catches up via
  //     foreground engine when the user reopens the app.
  // Bg publish — only feed (kind 1) + channel (kind 42) are safe to sign
  // and broadcast from this isolate (no native plugins required, gateway
  // watcher picks up the EventQueueModel row). DM (NIP-17) and private
  // channels (NIP-29 MLS) need main-isolate plugins, so we skip them in
  // bg; the foreground engine reactively picks up the same input next
  // time the app opens. One-shot DM/PC Ganas with no reactive trigger
  // won't fire from bg — known limitation.
  String? publishedEventId;
  if (gana.outputType == GanaOutputType.feed ||
      gana.outputType == GanaOutputType.channel) {
    if (privkeyHex == null || privkeyHex.isEmpty) {
      _log('  publish SKIPPED: no privkeyHex in bg (will retry foreground)');
    } else {
      _log('  publish IN-BG: ${gana.outputType.name} '
          '(signing locally, writing EventQueueModel)');
      publishedEventId = await _publishInBg(
        isar: isar,
        gana: gana,
        body: trimmed,
        privkeyHex: privkeyHex,
      );
      if (publishedEventId != null) {
        _log('  publish DONE: eventId=${_shortHex(publishedEventId)} '
            '(gateway broadcasts next watcher tick)');
      } else {
        _log('  publish FAILED in-bg (will retry foreground)');
      }
    }
  } else {
    _log('  publish SKIPPED: ${gana.outputType.name} requires main-isolate '
        'plugins (DM/MLS); foreground engine will handle on next trigger');
  }

  await _writeRun(
    isar: isar,
    runId: runId,
    ganaId: gana.ganaId,
    startedAt: startedAt,
    status: GanaRunStatus.succeeded,
    inputEventIds: inputs.map((n) => n.eventId).toList(),
    outputEventId: publishedEventId,
  );

  await _advanceCursor(
    isar: isar,
    ganaRow: ganaRow,
    inputs: inputs,
    publishedOutput: true,
  );
  _log('runOneGana END status=succeeded '
      'totalRunMs=${DateTime.now().difference(startedAt).inMilliseconds}');
}

// Tiny helpers used by the verbose log lines.
String _shortHex(String s) {
  if (s.length <= 12) return s;
  return '${s.substring(0, 8)}…${s.substring(s.length - 4)}';
}

String _previewBody(String s) {
  final flat = s.replaceAll('\n', ' \\n ');
  if (flat.length <= 80) return flat;
  return '${flat.substring(0, 80)}…';
}

/// Sign + enqueue a kind-1 (feed) or kind-42 (channel) event directly
/// from the bg isolate. Returns the resulting `eventId`, or null on
/// failure (in which case the caller falls back to the pending table).
///
/// We mirror the existing publish use cases' tag order so the broadcast
/// event re-serializes to the same SHA-256 as the signed eventId.
Future<String?> _publishInBg({
  required Isar isar,
  required GanaEntity gana,
  required String body,
  required String privkeyHex,
}) async {
  try {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (gana.outputType == GanaOutputType.feed) {
      final ev = Event.from(
        privkey: privkeyHex,
        kind: kNoteKind,
        content: body,
        tags: const <List<String>>[],
        createdAt: nowUnix,
      );
      final createdAt =
          DateTime.fromMillisecondsSinceEpoch(ev.createdAt * 1000);
      await isar.writeTxn(() async {
        // Local visibility — mirror PublishNoteUseCase step 1 so the
        // published note shows up in the feed immediately. Without this
        // the UI only ever sees the note if the relay echoes it back.
        await isar.noteModels.put(NoteModel(
          eventId: ev.id,
          sig: ev.sig,
          authorPubkey: ev.pubkey,
          content: ev.content,
          kind: kNoteKind,
          type: NoteType.text,
          eTagRefs: const [],
          pTagRefs: const [],
          tTags: const [],
          created: createdAt,
        ));
        // Relay broadcast.
        await isar.eventQueueModels.put(
          EventQueueModel()
            ..eventId = ev.id
            ..authorPubkey = ev.pubkey
            ..sig = ev.sig
            ..content = ev.content
            ..kind = kNoteKind
            ..eTagRefs = const []
            ..pTagRefs = const []
            ..tTags = const []
            ..created = createdAt
            ..enqueuedAt = DateTime.now(),
        );
      });
      return ev.id;
    }
    if (gana.outputType == GanaOutputType.channel) {
      final channelId = gana.outputChannelId;
      if (channelId == null) return null;
      final tags = <List<String>>[
        ['e', channelId, '', 'root'],
      ];
      final ev = Event.from(
        privkey: privkeyHex,
        kind: kChannelMessageKind,
        content: body,
        tags: tags,
        createdAt: nowUnix,
      );
      final createdAt =
          DateTime.fromMillisecondsSinceEpoch(ev.createdAt * 1000);
      await isar.writeTxn(() async {
        // Local visibility — same as feed branch above.
        await isar.noteModels.put(NoteModel(
          eventId: ev.id,
          sig: ev.sig,
          authorPubkey: ev.pubkey,
          content: ev.content,
          kind: kChannelMessageKind,
          channelId: channelId,
          type: NoteType.text,
          eTagRefs: [channelId],
          rootEventId: channelId,
          pTagRefs: const [],
          tTags: const [],
          created: createdAt,
        ));
        await isar.eventQueueModels.put(
          EventQueueModel()
            ..eventId = ev.id
            ..authorPubkey = ev.pubkey
            ..sig = ev.sig
            ..content = ev.content
            ..kind = kChannelMessageKind
            ..eTagRefs = [channelId]
            ..rootEventId = channelId
            ..pTagRefs = const []
            ..tTags = const []
            ..created = createdAt
            ..enqueuedAt = DateTime.now(),
        );
      });
      return ev.id;
    }
  } catch (e, st) {
    debugPrint('Gana bg tick: in-bg publish failed: $e\n$st');
  }
  return null;
}

// Run log + cursor advance delegate to the shared, isolate-agnostic
// [gana_run.dart] helpers so foreground and background can't drift.

Future<void> _writeRun({
  required Isar isar,
  required String runId,
  required String ganaId,
  required DateTime startedAt,
  required GanaRunStatus status,
  GanaSkipReason? skipReason,
  List<String> inputEventIds = const [],
  String? outputEventId,
  String? error,
}) =>
    writeGanaRun(
      isar: isar,
      runId: runId,
      ganaId: ganaId,
      startedAt: startedAt,
      status: status,
      skipReason: skipReason,
      inputEventIds: inputEventIds,
      outputEventId: outputEventId,
      error: error,
    );

Future<void> _advanceCursor({
  required Isar isar,
  required GanaModel ganaRow,
  required List<NoteModel> inputs,
  bool publishedOutput = false,
}) =>
    advanceGanaCursor(
      isar: isar,
      ganaId: ganaRow.ganaId,
      inputs: inputs,
      publishedOutput: publishedOutput,
    );
