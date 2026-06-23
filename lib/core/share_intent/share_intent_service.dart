import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Captures content shared INTO UNIUN from other apps (WhatsApp, Photos, Files,
/// browsers) via the OS share sheet.
///
/// Two entry points, mirroring `receive_sharing_intent`:
///  • [consumeInitial] — the payload the app was cold-started with (drained
///    once, then `reset()` so it does not re-fire on a later resume).
///  • [listen] — warm-start shares that arrive while the app is alive.
///
/// The UI layer ([HomePage]) owns the navigation decision; this service only
/// surfaces the raw [SharedMediaFile] batches. Kept here (core) rather than in a
/// feature module because it is an app-lifecycle concern wired at startup.
@lazySingleton
class ShareIntentService {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  /// Returns the cold-start share payload (empty when the app was launched
  /// normally). Calls `reset()` so the same payload is not replayed when the
  /// app is next resumed.
  Future<List<SharedMediaFile>> consumeInitial() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    ReceiveSharingIntent.instance.reset();
    return media;
  }

  /// Subscribes to warm-start shares. [onShare] fires once per non-empty batch.
  /// Idempotent — a second call does not add a second subscription.
  void listen(void Function(List<SharedMediaFile> files) onShare) {
    _sub ??= ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) onShare(files);
      },
      onError: (_) {},
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
