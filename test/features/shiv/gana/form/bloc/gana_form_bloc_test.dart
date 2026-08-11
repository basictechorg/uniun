import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/enum/gana_trigger_preset.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/followed_note/followed_note_entity.dart';
import 'package:uniun/domain/entities/gana/gana_entity.dart';
import 'package:uniun/domain/entities/group/group_entity.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/private_group/private_group_entity.dart';
import 'package:uniun/domain/usecases/dm_usecases.dart';
import 'package:uniun/domain/usecases/followed_note_usecases.dart';
import 'package:uniun/domain/usecases/gana_usecases.dart';
import 'package:uniun/domain/usecases/get_groups_usecase.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/private_group_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/features/shiv/gana/form/bloc/gana_form_bloc.dart';

class _MockUpsert extends Mock implements UpsertGanaUseCase {}

class _MockGetById extends Mock implements GetGanaByIdUseCase {}

class _MockDelete extends Mock implements DeleteGanaUseCase {}

class _MockGetManases extends Mock implements GetManasListUseCase {}

class _MockGetGroups extends Mock implements GetGroupsUseCase {}

class _MockGetPrivateGroups extends Mock implements GetPrivateGroupsUsecase {}

class _MockGetDms extends Mock implements GetDmConversationsUseCase {}

class _MockGetFollowed extends Mock implements GetAllFollowedNotesUseCase {}

class _MockGetProfile extends Mock implements GetProfileUseCase {}

class _MockRequestProfileFetch extends Mock
    implements RequestProfileFetchUseCase {}

GanaEntity _cloudGana({String ganaId = 'g-1'}) => GanaEntity(
      ganaId: ganaId,
      name: 'Digest bot',
      manasIds: const ['m-1'],
      taskPrompt: 'Summarize',
      outputType: GanaOutputType.feed,
      desiredModelId: 'claude-cloud-mini',
      desiredBackend: LlmBackendType.uniunCloud,
      triggerMode: GanaTriggerMode.oneShot,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Covers: [GanaFormBloc] model-override event handling (local/cloud/clear)
/// and its round-trip through load (edit mode) + submit (upsert payload).
void main() {
  setUpAll(() {
    registerFallbackValue(_cloudGana());
  });

  late _MockUpsert upsert;
  late _MockGetById getById;
  late _MockDelete delete;
  late _MockGetManases getManases;
  late _MockGetGroups getGroups;
  late _MockGetPrivateGroups getPrivateGroups;
  late _MockGetDms getDms;
  late _MockGetFollowed getFollowed;
  late _MockGetProfile getProfile;
  late _MockRequestProfileFetch requestProfileFetch;

  GanaFormBloc build() => GanaFormBloc(
        upsert,
        getById,
        delete,
        getManases,
        getGroups,
        getPrivateGroups,
        getDms,
        getFollowed,
        getProfile,
        requestProfileFetch,
      );

  setUp(() {
    upsert = _MockUpsert();
    getById = _MockGetById();
    delete = _MockDelete();
    getManases = _MockGetManases();
    getGroups = _MockGetGroups();
    getPrivateGroups = _MockGetPrivateGroups();
    getDms = _MockGetDms();
    getFollowed = _MockGetFollowed();
    getProfile = _MockGetProfile();
    requestProfileFetch = _MockRequestProfileFetch();

    when(() => getManases.call())
        .thenAnswer((_) async => const Right(<ManasEntity>[]));
    when(() => getGroups.call())
        .thenAnswer((_) async => const Right(<GroupEntity>[]));
    when(() => getPrivateGroups.execute())
        .thenAnswer((_) => Stream.value(const <PrivateGroupEntity>[]));
    when(() => getDms.call())
        .thenAnswer((_) async => const Right(<DmConversationEntity>[]));
    when(() => getFollowed.call())
        .thenAnswer((_) async => const Right(<FollowedNoteEntity>[]));
    when(() => upsert.call(any()))
        .thenAnswer((i) async => Right(i.positionalArguments.first as GanaEntity));
  });

  group('GanaFormModelChangedEvent', () {
    blocTest<GanaFormBloc, GanaFormState>(
      'picking a local model sets desiredModelId + desiredBackend=local',
      build: build,
      act: (b) => b.add(const GanaFormModelChangedEvent(
        'qwen3_06b',
        backend: LlmBackendType.localGemma,
      )),
      expect: () => [
        isA<GanaFormState>()
            .having((s) => s.desiredModelId, 'desiredModelId', 'qwen3_06b')
            .having((s) => s.desiredBackend, 'desiredBackend',
                LlmBackendType.localGemma),
      ],
    );

    blocTest<GanaFormBloc, GanaFormState>(
      'picking a cloud model sets desiredModelId + desiredBackend=uniunCloud',
      build: build,
      act: (b) => b.add(const GanaFormModelChangedEvent(
        'claude-cloud-mini',
        backend: LlmBackendType.uniunCloud,
      )),
      expect: () => [
        isA<GanaFormState>()
            .having((s) => s.desiredModelId, 'desiredModelId',
                'claude-cloud-mini')
            .having((s) => s.desiredBackend, 'desiredBackend',
                LlmBackendType.uniunCloud),
      ],
    );

    blocTest<GanaFormBloc, GanaFormState>(
      'picking "use active" (null) clears both desiredModelId and desiredBackend',
      build: build,
      seed: () => const GanaFormState(
        desiredModelId: 'claude-cloud-mini',
        desiredBackend: LlmBackendType.uniunCloud,
      ),
      act: (b) => b.add(const GanaFormModelChangedEvent(null)),
      expect: () => [
        isA<GanaFormState>()
            .having((s) => s.desiredModelId, 'desiredModelId', isNull)
            .having((s) => s.desiredBackend, 'desiredBackend', isNull),
      ],
    );
  });

  group('load (edit mode) round-trips desiredBackend', () {
    blocTest<GanaFormBloc, GanaFormState>(
      'a cloud-pinned Gana loads with desiredBackend=uniunCloud',
      build: build,
      setUp: () {
        when(() => getById.call('g-1'))
            .thenAnswer((_) async => Right(_cloudGana()));
      },
      act: (b) => b.add(const GanaFormLoadEvent('g-1')),
      verify: (b) {
        expect(b.state.desiredModelId, 'claude-cloud-mini');
        expect(b.state.desiredBackend, LlmBackendType.uniunCloud);
      },
    );
  });

  group('submit persists the cloud override', () {
    blocTest<GanaFormBloc, GanaFormState>(
      'canSave gana with a cloud model pin upserts an entity carrying it',
      build: build,
      act: (b) async {
        b.add(const GanaFormLoadEvent(null));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.add(const GanaFormNameChangedEvent('Digest bot'));
        b.add(const GanaFormTaskPromptChangedEvent('Summarize my notes'));
        b.add(const GanaFormToggleManasEvent('m-1'));
        // Standalone one-shot: no input source, fires on enable — needs no
        // interval/maxOutputs to satisfy canSave.
        b.add(const GanaFormTriggerPresetChangedEvent(
            GanaTriggerPreset.onceOnEnable));
        b.add(const GanaFormModelChangedEvent(
          'claude-cloud-mini',
          backend: LlmBackendType.uniunCloud,
        ));
        b.add(const GanaFormSubmitEvent());
      },
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        final captured =
            verify(() => upsert.call(captureAny())).captured.single
                as GanaEntity;
        expect(captured.desiredModelId, 'claude-cloud-mini');
        expect(captured.desiredBackend, LlmBackendType.uniunCloud);
        expect(captured.name, 'Digest bot');
      },
    );
  });
}
