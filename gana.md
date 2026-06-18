Phase 2 — Shiv Ganas (after Phase 1)
2A. Isolate architecture (the key part)
A dedicated Gana isolate mirroring the gateway, so the engine is decoupled from widget lifecycle and portable to a headless WorkManager callback.

New lib/features/shiv/gana/engine/gana_bootstrap.dart — GanaBootstrap.start() does Isolate.spawn(ganaEntryPoint, GanaInitMessage(isarDirectory, privkeyHex, pubkeyHex)), idempotent like GatewayBootstrap. Started from _HomePageState.initState right after GatewayBootstrap.start() (home_page.dart:33); stopped in dispose.
New lib/features/shiv/gana/engine/gana_isolate.dart — ganaEntryPoint(GanaInitMessage) opens its own Isar at the shared path, then runs the GanaEngine loop. Everything here is pure-Dart + Isar (no gemma): scheduling, input watching, cursor, prompt-building, output enqueue. Output is signed with the passed privkey (the nostr signing util is pure Dart) and written to EventQueueModel — the gateway isolate pumps it, exactly like Brahma.
Inference is the only gemma dependency → a pluggable backend (because gemma can't load twice):

abstract class GanaInferenceBackend {
  Future<String?> run(String prompt, {int maxTokens});
}
v1 BridgedInferenceBackend (app open): the Gana isolate writes a GanaInferenceJobModel row (status=queued) and watches it; a small main-isolate GanaInferenceServer (@lazySingleton, started in HomePage) watches queued jobs, runs GenerateOneShotUseCase (the single model instance, low lane, serialized with chat), writes the result back. One model, no double-load, app-open-only.
Future LocalGemmaInferenceBackend (background/WorkManager): when the app is killed there is no main isolate, so the headless isolate safely calls FlutterGemma.initialize() + generateOneShot itself. The engine code is identical; only the backend swaps, and a WorkManager entrypoint reuses ganaEntryPoint. (Requires verifying flutter_gemma works in a background isolate via RootIsolateToken/BackgroundIsolateBinaryMessenger — flagged in Known limitations.)
2B. Data layer
Enum lib/core/enum/gana_input_type.dart: channel, privateChannel, dm, user, followedNote.
Model lib/data/models/gana_model.dart — @Name('Gana'): ganaId(unique), name, manasId (FK→ManasModel.manasId), taskPrompt, inputType: GanaInputType? + inputRefId: String? (both null = standalone), outputChannelId, triggerReactive: bool, triggerIntervalMinutes: int?, enabled: bool, cursor (lastProcessedEventId?, lastProcessedCreated?, lastRunAt?), createdAt. (Cursor: lastProcessedCreated = monotonic "new since"; lastProcessedEventId = same-second tiebreak; lastRunAt = interval anchor so relaunch doesn't re-fire.)
Model lib/data/models/gana_run_model.dart — @Name('GanaRun'): runId(unique), ganaId(idx), startedAt(idx), status (running|succeeded|skipped|failed), inputEventIds: List<String>, outputEventId?, error?. Best-effort log; also the self-loop guard source.
Model lib/data/models/gana_inference_job_model.dart — @Name('GanaInferenceJob'): jobId(unique), ganaId, prompt, maxTokens, status (queued|running|done|failed), result?, error?, createdAt, completedAt?. The cross-isolate inference bridge.
Entities + repos + usecases for Gana and GanaRun under the standard layers (gana_usecases.dart: UpsertGanaUseCase, GetGanasUseCase, GetEnabledGanasUseCase, GetGanaByIdUseCase, DeleteGanaUseCase, AdvanceGanaCursorUseCase). Register all three schemas in isar_schemas.dart.
2C. Engine behavior (in the Gana isolate)
Lifecycle/reload: load enabled Ganas; per Gana wire reactive (noteModels.watchLazy() → debounced ~3s run) and/or interval (Timer.periodic). Watch ganaModels.watchLazy() (debounced ~500ms) → full reload on any create/edit/delete/toggle. UI only writes rows; it never calls the engine.

Input filter — _fetchNewInput(gana) = noteModels.filter().createdGreaterThan(cursor).…sortByCreated() capped ~20, drop leading note where eventId == lastProcessedEventId:

inputType	clause
channel	.channelIdEqualTo(refId).kindEqualTo(kChannelMessageKind)
privateChannel	.groupIdEqualTo(refId).kindEqualTo(kPrivateChannelKind)
dm	.conversationIdEqualTo(int.parse(refId)) (refId = stringified DmConversationModel.id)
user	.authorPubkeyEqualTo(refId).kindEqualTo(kNoteKind)
followedNote	.eTagRefsElementEqualTo(refId)
null	standalone — no input fetch
One run: guards → fetch new input (skip if has-input & empty) → load Manas → build direct-pack context (read manas.noteIds text from saved/own/draft Isar collections, pack under a token budget) → assemble prompt (task → INPUT MESSAGES → KNOWLEDGE → "write one channel message") → backend.run(prompt) → null/empty ⇒ skip, don't advance cursor → else enqueue output via CreateChannelMessageUseCase → advance cursor (lastProcessedCreated/EventId = last input, lastRunAt = now) → log GanaRun.

Guards: engine single-flight FIFO (one run at a time); skip if no active model; reactive debounce; reactive+interval coalesce via cursor.

Self-loop guard (highest risk — call out in review): in _fetchNewInput, drop notes where authorPubkey == self pubkey, and drop any eventId present as an outputEventId in GanaRun. Kills self-loops and Gana-to-Gana ping-pong.

2D. Scoped RAG (direct-pack, isolate-friendly)
v1 uses direct-pack only: a new lib/features/shiv/gana/engine/manas_context_loader.dart resolves manas.noteIds across savedNoteModels → noteModels → draftModels and packs the text under a budget — no embedder, no vector DB, so it runs entirely in the Gana isolate and transparently includes drafts. (Scoped-vector retrieval for very large Manas — threading allowedNoteIds through VectorRepository.search — is deferred; not needed while Manas are small and curated.)

2E. UI (in Shiv)
lib/features/shiv/gana/ (bloc/, pages/, widgets/).

Shiv drawer — new "Ganas" section. Add a Ganas section to the existing Shiv drawer (ShivHistoryDrawer, lib/features/shiv/chat/widgets/), driven by GanaListBloc (→ GetGanasUseCase):

lists all Ganas (name + enabled state);
a + button → opens the Gana create form;
tapping a Gana → opens the Gana detail/edit page.
Gana detail/edit page (GanaEditBloc → UpsertGanaUseCase / DeleteGanaUseCase): shows info about the Gana (its Manas, input source, output channel, triggers, last run from GanaRun), an editable form, and a delete button. Create and edit use the same form.

Form fields resolve: Manas (dropdown of GetManasListUseCase), input source (type + ref picker constrained to surfaces the user is already in — known channelModels/conversations/followed notes; or "none" for standalone), output channel (dropdown of channelModels), triggers (reactive switch + interval minutes), enabled.

New routes + l10n keys. UI only writes GanaModel/ManasModel rows; the Gana isolate engine reacts via its ganaModels.watchLazy() reload.
2F. Edge cases / Known limitations
gemma can't load twice → v1 inference bridges to the single main-isolate model; the engine is app-open-only until the background backend lands.
True background (WorkManager) needs flutter_gemma verified to run in a background isolate (RootIsolateToken); until then it's the future LocalGemmaInferenceBackend. Architecture is ready for the swap; the runtime capability is the open risk.
Private-channel input (kind 9023, Marmot/MLS): verify kind9021_25_handler.dart/marmot_mls_service.dart write decrypted content into NoteModel. If ciphertext at rest, defer that one input type; channel/dm/user/followedNote are confirmed plaintext.
Input must be a subscribed surface (gateway only writes rows for what it subscribes to) → constrain the pickers to joined channels/known conversations.
Duplicate-publish window: app killed between enqueue and cursor-advance ⇒ at most one re-publish next launch (relay dedups by event id). Acceptable v1.
2G. Verify Phase 2
Unit (test/features/gana/): input-filter per type + cursor advance + self-loop guard + manas_context_loader (resolves across saved/own/draft).
Bridge test: Gana isolate writes a job → main-isolate server completes it → engine reads result.
Manual e2e: model downloaded → create Manas → create Gana (Manas + input channel you're in + output channel + reactive + enabled) → post to input channel → the Gana's kind-42 appears in output channel → post to the output channel and confirm no loop → switch to interval-only standalone and confirm scheduled posts.
