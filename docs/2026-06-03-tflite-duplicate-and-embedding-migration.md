# Session log — UI fix, iOS device crash diagnosis, and embedding migration

**Date:** 2026-06-03
**Branch:** `feat/SHIV/V3`
**Scope:** Two pieces of work that ran back-to-back:
1. A small UI collision fix (Brahma FAB + Shiv input vs. the floating bottom nav).
2. A deep diagnosis of an iOS **device-only** `EXC_BAD_ACCESS` crash, traced to a duplicate TensorFlow Lite static link, and fixed by migrating Shiv's embedding from `tflite_flutter` to flutter_gemma's LiteRT embedder (bundled Gecko 110M model via Git LFS).

---

## Part 1 — UI fix: Brahma FAB + Shiv input colliding with the bottom nav

### Symptom
The Brahma "add new note" FAB and the Shiv chat input bar were overlapping the floating bottom navigation on some devices.

### Root cause
`FloatingNav` pads its bottom by `MediaQuery.padding.bottom` (the home-indicator safe area), so its **total height grows on devices with a home indicator** (iPhone X+, ~34px). But both overlay elements used **hardcoded** bottom offsets that ignored that inset:
- Shiv input: fixed `80.0` — less than the nav's real height (~88px) on home-indicator devices → overlap.
- Brahma FAB: fixed `bottom: 96` — left almost no gap above the taller nav.

### Fix (surgical, safe-area aware)
- `lib/features/shiv/chat/widgets/shiv_input_composer.dart` — closed-keyboard bottom padding `80.0` → `80.0 + MediaQuery.padding.bottom`. Keyboard-open case untouched (nav slides off-screen then).
- `lib/features/brahma/graph/pages/graph_page.dart` — FAB `bottom: 96` → `96 + MediaQuery.of(context).padding.bottom`.

No behavior change on devices without a home indicator (`padding.bottom == 0`).

---

## Part 2 — iOS device-only crash: duplicate TensorFlow Lite

### Symptoms observed (in order)
1. Native crash, repeated identically every run:
   ```
   thread #N, name = 'DartWorker', stop reason = EXC_BAD_ACCESS (code=50, address=0x...0c4)
   ->  ldur   x6, [x24, #0x37]      ; load a pointer out of an object
       ldursw x7, [x6, #0x6f]       ; read a 32-bit counter field
       add    x7, x7, #0x1          ; increment
       stur   w7, [x6, #0x6f]       ; write back
   ```
   A refcount-style field increment on a **garbage object pointer** — classic use-after-free / heap or symbol-table corruption in native code. Sometimes on `DartWorker` (background isolate), sometimes on the main thread.

2. The decisive log line:
   ```
   objc[]: Class TFLBufferConvert is implemented in both Runner (0x...) and Runner (0x...).
   This may cause spurious casting failures and mysterious crashes.
   ```

3. Sometimes instead of crashing:
   ```
   IsarError: Could not initialize IsarCore library ...
   Failed to lookup symbol 'isar_version': dlsym(RTLD_DEFAULT, isar_version): symbol not found
   ```

4. **Device-only**: never reproduced on the iOS Simulator, only on a physical `ios_arm64` device.

### Root cause — one bug behind all symptoms
TensorFlow Lite was statically linked into the single `Runner` binary **twice**:
- `tflite_flutter` → `TensorFlowLiteC` / `TensorFlowLiteSwift` (contains `TFLBufferConvert`, the TFLite Metal delegate class).
- `flutter_gemma` → `MediaPipeTasksGenAI` / `…GenAIC`, which **embed their own copy of TensorFlow Lite internally**.

With `use_frameworks! :linkage => :static` (in `ios/Podfile`), every pod is merged into `Runner`. Two identical static `TFLBufferConvert` symbols in one binary → the Objective-C runtime can't disambiguate the classes and the exported symbol table is corrupted. That explains everything:
- **Device-only**: the corruption is in the `ios-arm64` static link; the simulator uses a different framework slice.
- **Non-deterministic symptoms**: a corrupted symbol table sometimes faults during a refcount op (`EXC_BAD_ACCESS`), sometimes makes `dlsym(RTLD_DEFAULT, isar_version)` fail. Isar was collateral damage, not the cause.

### Approaches ruled out
- **Dynamic linkage** (`use_frameworks!` without `:linkage => :static`): `pod install` fails — MediaPipe ships as a **static-only xcframework**, so CocoaPods refuses to dynamically link it, and its embedded TFLite can't be separated.
- **Podfile/linker dedup**: impossible — MediaPipe embeds TFLite *inside* its static binary, so CocoaPods can't dedupe it the way Gradle does on Android.
- **Clean rebuild alone** (`flutter clean`, clear DerivedData + `.symlinks`, reinstall pods): did not fix it — proving it's structural, not a stale build.

**Conclusion:** the only durable fix is to stop linking TensorFlow Lite twice → remove `tflite_flutter` and run embeddings through flutter_gemma's own LiteRT runtime.

---

## Part 3 — Embedding migration (tflite_flutter → flutter_gemma LiteRT)

### Research finding
`flutter_gemma 0.16.3` ships a first-class, mobile-implemented embedding API on the **same LiteRT runtime** already inside flutter_gemma:
- `FlutterGemma.installEmbedder().modelFromAsset(...).tokenizerFromAsset(...).install()` (idempotent)
- `FlutterGemma.getActiveEmbedder()` → `EmbeddingModel`
- `EmbeddingModel.generateEmbedding(text, taskType: ...)` → `List<double>`
- `TaskType.retrievalQuery` / `retrievalDocument` (asymmetric prefixes)

Using it deletes `tflite_flutter` → one TFLite in the binary → duplicate `TFLBufferConvert` becomes structurally impossible.

### Model decision
The embedder tokenizes natively with a **SentencePiece** tokenizer (not BERT `vocab.txt`), so the old `all_minilm_l6_v2.tflite` + `vocab.txt` (384-dim) couldn't be reused.

Decisions made during the session:
- First chose **EmbeddingGemma 300M** — but Google's repos are **gated** on Hugging Face (HTTP 401 without auth/license), bad for both runtime download and bundling.
- Switched to **`litert-community/Gecko-110m-en`** — smaller (110M), **ungated** (freely redistributable, so bundlable), in flutter_gemma's catalog.
- Chose to **bundle** the model (offline-first, no runtime download, sidesteps gating) at the **1024-dim** variant.

Measured Gecko sizes (HEAD `Content-Length`):
| Variant | Size | Dim |
|---|---|---|
| Gecko_256_quant | 108 MB | 256 |
| Gecko_512_quant | 114 MB | 512 |
| **Gecko_1024_quant (chosen)** | **138 MB** | **1024** |
| sentencepiece.model | 776 KB | — |

### Code & asset changes
- **Model files** committed via **Git LFS**:
  - `assets/models/embedding/gecko_1024_quant.tflite` (139 MB, verified `TFL3` LiteRT magic)
  - `assets/models/embedding/sentencepiece.model` (776 KB)
  - `.gitattributes` tracks `assets/models/embedding/*.tflite` and `*.model` via LFS.
- `pubspec.yaml`:
  - Removed `tflite_flutter: ^0.12.0`.
  - Registered asset dir `assets/models/embedding/`.
- `lib/features/shiv/rag/embedding/embedding_service.dart` — rewritten:
  - `ensureInstalled()` installs the bundled asset embedder (idempotent); `init()` then `getActiveEmbedder()`.
  - `embed(text, {bool isDocument})` → `generateEmbedding` with the right `TaskType`; keeps L2-normalize.
  - Public consts `modelAsset` / `tokenizerAsset`; `embeddingDim = 1024`.
  - Deleted the TFLite `Interpreter` and the hand-rolled WordPiece tokenizer/vocab.
- `lib/features/shiv/rag/embedding/embedding_model_downloader.dart` — repurposed from an HTTP downloader to a bundled-asset installer (pre-warm during the LLM-download UX). Same class/method names (`downloadIfNeeded()`, `isDownloaded()`) so the `SelectAIModelCubit` wiring is untouched.
- `lib/domain/usecases/vector_usecases.dart` — stored note content now embeds with `isDocument: true`.
- `lib/data/datasources/tostore_module.dart` — vector dimension `384 → 1024`; DB path now carries the dimension (`tostore_1024d`) so any future model/dimension change auto-creates a fresh store. Old vectors are abandoned; notes re-embed as they flow through `EmbedAndStoreNoteUseCase`.

### Pod / dependency outcome
After removing `tflite_flutter` and `pod install`:
- Gone from `Podfile.lock`: `TensorFlowLiteC`, `TensorFlowLiteSwift`, `TensorFlowLiteSelectTfOps`, `tflite_flutter`.
- Remaining: only `MediaPipeTasksGenAI` / `…GenAIC` (single embedded LiteRT).
- Pod count 19 → 16. Duplicate `TFLBufferConvert` is now structurally impossible.

### Verification done
- `flutter analyze` on all changed files: **No issues found**.
- `Podfile.lock` confirmed free of standalone TensorFlow Lite pods.
- Git LFS confirmed catching the model files (`git check-attr filter` → `lfs`; `git lfs ls-files` lists them).
- Model file integrity verified (`TFL3` magic bytes, not an HTML error page).

---

## Outstanding / for the team

- **Test on the physical device** (`flutter run`): confirm no `TFLBufferConvert ... in both` warning, no `isar_version` error, no `EXC_BAD_ACCESS`, and Shiv RAG works offline on first launch (look for `📦 Embedding: install complete ✅`).
- **Git LFS is mandatory for everyone + CI.** Clones without `git lfs install` / `git lfs pull` get a pointer file instead of the real model → the build bundles the pointer and embeddings silently fail. CI must `git lfs install` (and pull) before `flutter build`.
- **App size grows ~139 MB** (plus a one-time on-device copy when flutter_gemma installs the asset). This was an accepted trade for offline-on-first-launch. Smaller Gecko variants (256/512-dim) are available if needed.
- **Stale comments**: a few "all-MiniLM-L6-v2" mentions remain in Shiv model-select comments — cosmetic only, left untouched to keep the diff surgical.
- Build-config churn during diagnosis (pod regen, DerivedData clear) ended back at the original `use_frameworks! :linkage => :static`; only `Podfile.lock` differs (the standalone TFLite pods are now absent, as intended).

---

## Files touched (summary)

```
lib/features/shiv/chat/widgets/shiv_input_composer.dart      # UI: safe-area bottom pad
lib/features/brahma/graph/pages/graph_page.dart              # UI: FAB safe-area offset
lib/features/shiv/rag/embedding/embedding_service.dart       # embeddings via flutter_gemma LiteRT
lib/features/shiv/rag/embedding/embedding_model_downloader.dart  # bundled-asset installer
lib/domain/usecases/vector_usecases.dart                     # isDocument: true
lib/data/datasources/tostore_module.dart                     # 1024-dim, per-dim DB path
pubspec.yaml                                                 # -tflite_flutter, +asset dir
.gitattributes                                               # Git LFS tracking
assets/models/embedding/gecko_1024_quant.tflite              # bundled model (LFS)
assets/models/embedding/sentencepiece.model                  # bundled tokenizer (LFS)
ios/Podfile.lock                                             # standalone TFLite pods removed
```
