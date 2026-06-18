import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/local_llm_runner.dart';
import 'package:uniun/features/shiv/gana/inference/gana_inference_protocol.dart';

/// Main-isolate inference bridge for the Gana engine.
///
/// The engine isolate sends [GanaInferenceRequest] over [sendPort]; this
/// server reads them on its `ReceivePort`, runs inference on the active
/// flutter_gemma model via [AIModelRunner.generateOneShot] (low-priority
/// lane — Shiv chat preempts), and replies on `req.replyPort`.
///
/// **v1 shortcut (documented)**: this server uses plain-text generation +
/// `<NOOP>` parsing, not function calling. The Gana plan calls for a
/// `publish_message(body)` tool, but wiring full tool-call schema through
/// flutter_gemma's API is a separate piece of work. The prompt already
/// nudges the model to either emit the message body verbatim or the
/// sentinel `<NOOP>`. Upgrade path: replace `_runOneShot` with a tool-
/// schema variant once `flutter_gemma_mediapipe` 1.0.x is in the project.
@lazySingleton
class GanaInferenceServer {
  GanaInferenceServer(this._runner, this._settings);

  final AIModelRunner _runner;
  final AppSettingsStore _settings;

  ReceivePort? _port;
  bool _started = false;

  /// SendPort the engine isolate uses to deliver requests. Valid only
  /// after [start] completes.
  SendPort get sendPort {
    final p = _port;
    if (p == null) {
      throw StateError('GanaInferenceServer not started');
    }
    return p.sendPort;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _port = ReceivePort('gana-inference');
    _port!.listen(_onMessage);
    debugPrint('GanaInferenceServer started');
  }

  Future<void> stop() async {
    _port?.close();
    _port = null;
    _started = false;
  }

  Future<void> _onMessage(dynamic msg) async {
    if (msg is! GanaInferenceRequest) {
      debugPrint('GanaInferenceServer: ignored non-request: ${msg.runtimeType}');
      return;
    }
    final req = msg;
    GanaInferenceResponse response;
    try {
      response = await _handle(req);
    } catch (e, st) {
      debugPrint('GanaInferenceServer: handler threw: $e\n$st');
      response = GanaInferenceResponse.failed(e.toString());
    }
    try {
      req.replyPort.send(response);
    } catch (_) {
      // engine isolate closed before we replied — drop silently
    }
  }

  Future<GanaInferenceResponse> _handle(GanaInferenceRequest req) async {
    // Gate 1: an active model must be loaded.
    if (!FlutterGemma.hasActiveModel()) {
      return GanaInferenceResponse.noActiveModel();
    }

    // Gate 2: per-Gana model preference.
    final activeId = _settings.activeModelId?.name;
    if (req.expectedModelId != null &&
        activeId != null &&
        req.expectedModelId != activeId) {
      return GanaInferenceResponse.modelMismatch();
    }

    // Cancellation: lean on `AIModelRunner.generateOneShot`, which already
    // returns null when preempted by Shiv chat or when the underlying
    // model context goes away mid-generation. Engine treats `cancelled` as
    // `GanaSkipReason.modelSwapped` and does NOT advance the cursor.
    final text = await _runner.generateOneShot(
      req.prompt,
      maxTokens: req.maxTokens ?? 1024,
    );
    if (text == null) return GanaInferenceResponse.cancelled();
    return GanaInferenceResponse.ok(text);
  }
}
