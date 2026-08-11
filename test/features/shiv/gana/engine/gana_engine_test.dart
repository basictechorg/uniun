import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/app_settings_store.dart';
import 'package:uniun/data/datasources/llm/local_llm_runner.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';
import 'package:uniun/domain/usecases/create_group_message_usecase.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/vector_usecases.dart';
import 'package:uniun/features/mesh/sync/mesh_event_signer.dart';
import 'package:uniun/features/shiv/gana/engine/gana_engine.dart';
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';

import '../../../../_helpers/fixtures.dart';
import '../../../../_helpers/isar_test_harness.dart';
import '../../../../_helpers/stub_user_repository.dart';

class _MockRunner extends Mock implements AIModelRunner {}

class _MockSettings extends Mock implements AppSettingsStore {}

class _MockPublishNote extends Mock implements PublishNoteUseCase {}

class _MockGroupMessage extends Mock implements CreateGroupMessageUseCase {}

class _MockDm extends Mock implements SendDmUseCase {}

class _MockPrivateGroup extends Mock implements SendPrivateGroupMessageUsecase {}

class _MockEmbedAndStore extends Mock implements EmbedAndStoreNoteUseCase {}

class _MockManasLoader extends Mock implements ManasContextLoader {}

class _MockSigner extends Mock implements MeshEventSigner {}

class _MockGenerateOneShot extends Mock implements GenerateOneShotUseCase {}

class _MockIsCloudConnected extends Mock implements IsUniunCloudConnectedUseCase {}

class _MockGetActiveLlmModel extends Mock implements GetActiveLlmModelUseCase {}

/// Covers: [GanaEngine]'s cloud/local dispatch gate (cloud routes through
/// [GenerateOneShotUseCase] with a backend/model override and skips the
/// on-device gate; local is unaffected — `FlutterGemma.hasActiveModel()` is
/// false in this plain-Dart environment, no platform channel needed since
/// that call reads a static in-memory field); one-shot auto-disable; cloud
/// output routing through every [GanaOutputType] (feed/group/privateGroup/
/// dm); the reactive input-filter path (fires on a matching new note, skips
/// `noNewInput` on a non-matching one); and the recurring `maxOutputs` cap
/// (skips + auto-disables ahead of even a genuinely new input).
void main() {
  setUpAll(() {
    registerFallbackValue(aNote());
    registerFallbackValue(const GenerateOneShotInput(prompt: ''));
    registerFallbackValue(('', ''));
    registerFallbackValue(LlmTaskKind.gana);
    registerFallbackValue(
      const CreateGroupMessageInput(groupId: '', content: '', privateKey: ''),
    );
    registerFallbackValue(SendDmParams(otherPubkey: '', content: ''));
    registerFallbackValue(<String, dynamic>{});
  });

  late Isar isar;
  late _MockRunner runner;
  late _MockSettings settings;
  late _MockPublishNote publishNote;
  late _MockGroupMessage groupMessage;
  late _MockDm dm;
  late _MockPrivateGroup privateGroup;
  late _MockEmbedAndStore embedAndStore;
  late _MockManasLoader manasLoader;
  late _MockSigner signer;
  late _MockGenerateOneShot generateOneShot;
  late _MockIsCloudConnected isCloudConnected;
  late _MockGetActiveLlmModel getActiveLlmModel;
  late StubUserRepository userRepo;
  late GanaEngine engine;

  setUp(() async {
    isar = await openTestIsar();
    runner = _MockRunner();
    settings = _MockSettings();
    publishNote = _MockPublishNote();
    groupMessage = _MockGroupMessage();
    dm = _MockDm();
    privateGroup = _MockPrivateGroup();
    embedAndStore = _MockEmbedAndStore();
    manasLoader = _MockManasLoader();
    signer = _MockSigner();
    generateOneShot = _MockGenerateOneShot();
    isCloudConnected = _MockIsCloudConnected();
    getActiveLlmModel = _MockGetActiveLlmModel();
    userRepo = StubUserRepository();

    // Default: no globally active model resolvable — matches the old
    // behavior (an unpinned Gana still falls back to the local gate)
    // unless a specific test overrides this.
    when(() => getActiveLlmModel.call()).thenAnswer((_) async => const Right(null));

    when(() => signer.currentCodec()).thenAnswer((_) async => null);
    when(() => signer.sign(
          kind: any(named: 'kind'),
          dTag: any(named: 'dTag'),
          content: any(named: 'content'),
        )).thenAnswer((_) async => null);
    when(() => embedAndStore.call(any())).thenAnswer((_) async {});
    when(() => publishNote.call(any()))
        .thenAnswer((_) async => Right(aNote()));
    when(() => manasLoader.merge(
          manasIds: any(named: 'manasIds'),
          budget: any(named: 'budget'),
          relevanceQuery: any(named: 'relevanceQuery'),
        )).thenAnswer((_) async => const []);

    engine = GanaEngine(
      isar,
      runner,
      settings,
      userRepo,
      publishNote,
      groupMessage,
      dm,
      privateGroup,
      embedAndStore,
      manasLoader,
      signer,
      generateOneShot,
      isCloudConnected,
      getActiveLlmModel,
    );
  });

  tearDown(() async {
    await engine.stop();
    // GanaEngine.start() debounces schedule rebuilds on a local Timer that
    // `stop()` doesn't reach (it's not stored on the instance) — give any
    // in-flight 500ms debounce a beat to fire against a still-open Isar
    // before closing it, or it throws "Isar instance has already been
    // closed" after this test has already reported its result.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await isar.close(deleteFromDisk: true);
  });

  Future<void> seedGana({
    required String ganaId,
    LlmBackendType? desiredBackend,
    String? desiredModelId,
    GanaOutputType outputType = GanaOutputType.feed,
    String? outputGroupId,
    String? outputPrivateGroupId,
    int? outputDmConversationId,
    GanaInputType? inputType,
    String? inputRefId,
    bool triggerReactive = false,
    GanaTriggerMode triggerMode = GanaTriggerMode.oneShot,
    int? maxOutputs,
  }) async {
    final now = DateTime.now();
    await isar.writeTxn(() async {
      await isar.ganaModels.put(
        GanaModel()
          ..ganaId = ganaId
          ..name = 'Test Gana'
          ..taskPrompt = 'Say something'
          ..outputType = outputType
          ..outputGroupId = outputGroupId
          ..outputPrivateGroupId = outputPrivateGroupId
          ..outputDmConversationId = outputDmConversationId
          ..desiredBackend = desiredBackend
          ..desiredModelId = desiredModelId
          ..inputType = inputType
          ..inputRefId = inputRefId
          ..triggerReactive = triggerReactive
          ..triggerMode = triggerMode
          ..maxOutputs = maxOutputs
          ..enabled = true
          ..createdAt = now
          ..updatedAt = now,
      );
    });
  }

  /// A standalone (no input source) one-shot Gana — fires immediately once
  /// [GanaEngine.start] rebuilds the schedule and sees it enabled, with no
  /// interval/reactive trigger config needed.
  Future<void> seedStandaloneGana({
    required String ganaId,
    LlmBackendType? desiredBackend,
    String? desiredModelId,
  }) =>
      seedGana(
        ganaId: ganaId,
        desiredBackend: desiredBackend,
        desiredModelId: desiredModelId,
      );

  Future<void> seedNote({
    required String eventId,
    required String authorPubkey,
    String content = 'hello',
  }) async {
    await isar.writeTxn(() async {
      await isar.noteModels.put(NoteModel(
        eventId: eventId,
        sig: 'sig',
        authorPubkey: authorPubkey,
        content: content,
        kind: kNoteKind,
        type: NoteType.text,
        eTagRefs: const [],
        pTagRefs: const [],
        tTags: const [],
        created: DateTime.now(),
      ));
    });
  }

  Future<GanaRunModel?> waitForRun(
    String ganaId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final row =
          await isar.ganaRunModels.filter().ganaIdEqualTo(ganaId).findFirst();
      if (row != null) return row;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return null;
  }

  group('cloud-pinned Gana', () {
    test('not connected to UNIUN Cloud → skipped(cloudUnavailable), never '
        'calls generateOneShot or publishes', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => false);
      await seedStandaloneGana(
        ganaId: 'cloud-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
      );

      await engine.start();
      final run = await waitForRun('cloud-1');

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.skipped);
      expect(run.skipReason, GanaSkipReason.cloudUnavailable);
      verifyNever(() => generateOneShot.call(any()));
      verifyNever(() => publishNote.call(any()));
    });

    test('connected but no desiredModelId → skipped(cloudUnavailable)',
        () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      await seedStandaloneGana(
        ganaId: 'cloud-2',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: null,
      );

      await engine.start();
      final run = await waitForRun('cloud-2');

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.skipped);
      expect(run.skipReason, GanaSkipReason.cloudUnavailable);
      verifyNever(() => generateOneShot.call(any()));
    });

    test('connected + modelId set → calls generateOneShot with the backend/'
        'model override, publishes the result, skips the on-device gate',
        () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('Cloud-generated reply'));
      await seedStandaloneGana(
        ganaId: 'cloud-3',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
      );

      await engine.start();
      final run = await waitForRun('cloud-3');

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.succeeded);
      expect(run.outputEventId, isNotNull);

      final captured = verify(() => generateOneShot.call(captureAny()))
          .captured
          .single as GenerateOneShotInput;
      expect(captured.kind, LlmTaskKind.gana);
      expect(captured.backendOverride, LlmBackendType.uniunCloud);
      expect(captured.modelIdOverride, 'claude-cloud-mini');

      verify(() => publishNote.call(any())).called(1);
      // The on-device gate must never be consulted for a cloud-pinned run.
      verifyNever(() => runner.generateOneShot(any(),
          kind: any(named: 'kind'), maxTokens: any(named: 'maxTokens')));
    });
  });

  group('local (non-cloud) Gana — unaffected by the cloud gate', () {
    test('no active on-device model in this test process → '
        'skipped(noActiveModel), never touches the cloud use cases',
        () async {
      // desiredBackend left null (legacy/local row).
      await seedStandaloneGana(ganaId: 'local-1');

      await engine.start();
      final run = await waitForRun('local-1');

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.skipped);
      expect(run.skipReason, GanaSkipReason.noActiveModel);
      verifyNever(() => generateOneShot.call(any()));
      verifyNever(() => isCloudConnected.call());
    });
  });

  group('fully unset Gana (no pin at all) follows the global active backend',
      () {
    test('global active backend is cloud → routes through cloud using the '
        'globally active cloud model, without ever pinging the local gate',
        () async {
      when(() => getActiveLlmModel.call()).thenAnswer((_) async => const Right(
            LlmModelInfo(
              id: 'global-cloud-model',
              displayName: 'Global Cloud Model',
              backend: LlmBackendType.uniunCloud,
            ),
          ));
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('Followed the global switch'));
      // desiredBackend/desiredModelId both left null — no per-agent pin.
      await seedStandaloneGana(ganaId: 'unset-1');

      await engine.start();
      final run = await waitForRun('unset-1');

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.succeeded);
      final captured = verify(() => generateOneShot.call(captureAny()))
          .captured
          .single as GenerateOneShotInput;
      expect(captured.backendOverride, LlmBackendType.uniunCloud);
      expect(captured.modelIdOverride, 'global-cloud-model');
    });

    test('global active backend is local → unchanged local-gate behavior',
        () async {
      when(() => getActiveLlmModel.call()).thenAnswer((_) async => const Right(
            LlmModelInfo(
              id: 'qwen25_05b',
              displayName: 'Qwen3',
              backend: LlmBackendType.localGemma,
            ),
          ));
      await seedStandaloneGana(ganaId: 'unset-2');

      await engine.start();
      final run = await waitForRun('unset-2');

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.skipped);
      expect(run.skipReason, GanaSkipReason.noActiveModel);
      verifyNever(() => isCloudConnected.call());
    });

    test('a legacy explicit local pin (desiredModelId set, desiredBackend '
        'null) does NOT follow the global backend even if it is cloud',
        () async {
      when(() => getActiveLlmModel.call()).thenAnswer((_) async => const Right(
            LlmModelInfo(
              id: 'global-cloud-model',
              displayName: 'Global Cloud Model',
              backend: LlmBackendType.uniunCloud,
            ),
          ));
      await seedGana(
        ganaId: 'legacy-local-pin',
        desiredModelId: 'gemma4E2b', // set, but desiredBackend left null
      );

      await engine.start();
      final run = await waitForRun('legacy-local-pin');

      // Still resolves local (FlutterGemma.hasActiveModel() is false here),
      // never even asks whether the global backend is cloud-relevant beyond
      // the initial resolution check — the point is it does NOT silently
      // switch this explicitly-pinned-local Gana over to cloud.
      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.skipped);
      expect(run.skipReason, GanaSkipReason.noActiveModel);
      verifyNever(() => isCloudConnected.call());
      verifyNever(() => getActiveLlmModel.call());
    });
  });

  group('one-shot auto-disable', () {
    test('a one-shot Gana disables itself after a successful publish',
        () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('Done'));
      await seedStandaloneGana(
        ganaId: 'oneshot-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
      );

      await engine.start();
      final run = await waitForRun('oneshot-1');
      expect(run?.status, GanaRunStatus.succeeded);

      // The run log write and the cursor-advance write (which flips
      // `enabled`) are two separate, sequential writes — give the second
      // one a moment to land after the run row appears.
      GanaModel? row;
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline)) {
        row = await isar.ganaModels
            .filter()
            .ganaIdEqualTo('oneshot-1')
            .findFirst();
        if (row?.enabled == false) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(row!.enabled, isFalse);
    });
  });

  group('cloud output routing — every GanaOutputType', () {
    test('group output publishes via CreateGroupMessageUseCase with the '
        'cloud-generated body', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('Group reply'));
      when(() => groupMessage.call(any()))
          .thenAnswer((_) async => Right(aNote()));
      await seedGana(
        ganaId: 'group-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
        outputType: GanaOutputType.group,
        outputGroupId: 'group-abc',
      );

      await engine.start();
      final run = await waitForRun('group-1');

      expect(run?.status, GanaRunStatus.succeeded);
      final captured = verify(() => groupMessage.call(captureAny()))
          .captured
          .single as CreateGroupMessageInput;
      expect(captured.groupId, 'group-abc');
      expect(captured.content, 'Group reply');
      verifyNever(() => publishNote.call(any()));
      verifyNever(() => dm.call(any()));
    });

    test('privateGroup output publishes via SendPrivateGroupMessageUsecase',
        () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('Private reply'));
      when(() => privateGroup.execute(
            groupId: any(named: 'groupId'),
            content: any(named: 'content'),
            authorPubkey: any(named: 'authorPubkey'),
            privkeyHex: any(named: 'privkeyHex'),
          )).thenAnswer((_) async {});
      await seedGana(
        ganaId: 'pg-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
        outputType: GanaOutputType.privateGroup,
        outputPrivateGroupId: 'pg-abc',
      );

      await engine.start();
      final run = await waitForRun('pg-1');

      expect(run?.status, GanaRunStatus.succeeded);
      expect(run?.outputEventId, isNotNull);
      verify(() => privateGroup.execute(
            groupId: 'pg-abc',
            content: 'Private reply',
            authorPubkey: any(named: 'authorPubkey'),
            privkeyHex: any(named: 'privkeyHex'),
          )).called(1);
    });

    test('dm output publishes via SendDmUseCase against an existing conversation',
        () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('DM reply'));
      when(() => dm.call(any())).thenAnswer((_) async => const Right(unit));
      final conv = DmConversationModel()..otherPubkey = 'bob-pubkey';
      await isar.writeTxn(() async {
        await isar.dmConversationModels.put(conv);
      });
      await seedGana(
        ganaId: 'dm-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
        outputType: GanaOutputType.dm,
        outputDmConversationId: conv.id,
      );

      await engine.start();
      final run = await waitForRun('dm-1');

      expect(run?.status, GanaRunStatus.succeeded);
      final captured =
          verify(() => dm.call(captureAny())).captured.single as SendDmParams;
      expect(captured.otherPubkey, 'bob-pubkey');
      expect(captured.content, 'DM reply');
    });
  });

  group('reactive (input-driven) cloud Gana', () {
    test('a new note from the watched user fires the Gana via the cloud '
        'override', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      when(() => generateOneShot.call(any()))
          .thenAnswer((_) async => const Right('Reacted via cloud'));
      await seedGana(
        ganaId: 'reactive-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
        inputType: GanaInputType.user,
        inputRefId: 'watched-author',
        triggerReactive: true,
        triggerMode: GanaTriggerMode.recurring,
        maxOutputs: 10,
      );

      await engine.start();
      await seedNote(eventId: 'note-from-watched', authorPubkey: 'watched-author');

      final run =
          await waitForRun('reactive-1', timeout: const Duration(seconds: 8));

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.succeeded);
      final captured = verify(() => generateOneShot.call(captureAny()))
          .captured
          .single as GenerateOneShotInput;
      expect(captured.backendOverride, LlmBackendType.uniunCloud);
    });

    test('a note from someone other than the watched user → skip(noNewInput), '
        'never calls generateOneShot', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      await seedGana(
        ganaId: 'reactive-2',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
        inputType: GanaInputType.user,
        inputRefId: 'watched-author-with-no-notes',
        triggerReactive: true,
        triggerMode: GanaTriggerMode.recurring,
        maxOutputs: 10,
      );

      await engine.start();
      // Triggers the reactive watcher (any note write does), but doesn't
      // match the watched author — GanaInputFilter finds nothing.
      await seedNote(eventId: 'unrelated-note', authorPubkey: 'someone-else');

      final run =
          await waitForRun('reactive-2', timeout: const Duration(seconds: 8));

      expect(run, isNotNull);
      expect(run!.status, GanaRunStatus.skipped);
      expect(run.skipReason, GanaSkipReason.noNewInput);
      verifyNever(() => generateOneShot.call(any()));
    });
  });

  group('recurring maxOutputs cap', () {
    test('a recurring Gana already at its maxOutputs cap skips and '
        'auto-disables, even with genuinely new input waiting', () async {
      when(() => isCloudConnected.call()).thenAnswer((_) async => true);
      await seedGana(
        ganaId: 'capped-1',
        desiredBackend: LlmBackendType.uniunCloud,
        desiredModelId: 'claude-cloud-mini',
        inputType: GanaInputType.user,
        inputRefId: 'watched-author',
        triggerReactive: true,
        triggerMode: GanaTriggerMode.recurring,
        maxOutputs: 2,
      );
      // Two prior successful publishes already meet the cap.
      await isar.writeTxn(() async {
        for (var i = 0; i < 2; i++) {
          await isar.ganaRunModels.put(
            GanaRunModel()
              ..runId = 'prior-$i'
              ..ganaId = 'capped-1'
              ..startedAt = DateTime.now()
              ..status = GanaRunStatus.succeeded
              ..outputEventId = 'prior-evt-$i',
          );
        }
      });

      await engine.start();
      await seedNote(eventId: 'new-note', authorPubkey: 'watched-author');

      GanaRunModel? newRun;
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline)) {
        final rows = await isar.ganaRunModels
            .filter()
            .ganaIdEqualTo('capped-1')
            .findAll();
        final extra =
            rows.where((r) => !r.runId.startsWith('prior-')).toList();
        if (extra.isNotEmpty) {
          newRun = extra.first;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(newRun, isNotNull);
      expect(newRun!.status, GanaRunStatus.skipped);
      expect(newRun.skipReason, GanaSkipReason.maxOutputsReached);
      verifyNever(() => generateOneShot.call(any()));

      // `_disable` is a separate write after the run log — give it a moment.
      GanaModel? row;
      final disableDeadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(disableDeadline)) {
        row = await isar.ganaModels
            .filter()
            .ganaIdEqualTo('capped-1')
            .findFirst();
        if (row?.enabled == false) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(row!.enabled, isFalse);
    });
  });
}
