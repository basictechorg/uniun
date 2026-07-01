import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// The backend flutter_gemma should *prefer* when opening a model or embedder.
///
/// On **Android** the GPU (LiteRT / OpenCL) delegate crashes the process
/// natively on many devices — a SIGSEGV that no Dart `try/catch` can recover
/// from, so the usual GPU→CPU fallback at the call site never gets a chance to
/// run and the whole app goes down. We therefore prefer CPU straight away on
/// Android.
///
/// On **iOS** the Metal delegate is safe (failures there surface as catchable
/// Dart exceptions), so we keep GPU and let each call site fall back to CPU if
/// a particular model/device can't use it.
PreferredBackend get preferredLlmBackend =>
    defaultTargetPlatform == TargetPlatform.android
        ? PreferredBackend.cpu
        : PreferredBackend.gpu;
