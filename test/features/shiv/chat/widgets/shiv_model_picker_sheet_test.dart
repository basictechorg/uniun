import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/entities/llm/llm_model_info.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_model_picker_sheet.dart';
import 'package:uniun/features/shiv/model_select/utils/ai_model_l10n.dart';
import 'package:uniun/l10n/app_localizations.dart';

class _MGetActiveBackend extends Mock implements GetActiveLlmBackendUseCase {}

class _MIsCloudConnected extends Mock implements IsUniunCloudConnectedUseCase {}

class _MListCloud extends Mock implements ListCloudLlmModelsUseCase {}

class _MGetAvailable extends Mock implements GetAvailableAIModelsUseCase {}

class _MGetDownloaded extends Mock implements GetDownloadedModelIdsUseCase {}

class _MGetActiveLocal extends Mock implements GetActiveAIModelUseCase {}

class _MGetActiveLlmModel extends Mock implements GetActiveLlmModelUseCase {}

class _MSetBackend extends Mock implements SetActiveLlmBackendUseCase {}

class _MSetModel extends Mock implements SetActiveLlmModelUseCase {}

AIModelEntity _local(AIModelId id) => AIModelEntity(
      modelId: id,
      sizeLabel: '600 MB',
      sizeBytes: 600000000,
      tier: AIModelTier.lite,
      isRecommended: true,
      optimization: AIModelOptimization.cpu,
      downloadUrl: 'https://example.com/model.bin',
      isDownloaded: true,
    );

LlmModelInfo _cloud(String id, String name) => LlmModelInfo(
      id: id,
      displayName: name,
      backend: LlmBackendType.uniunCloud,
    );

/// Covers: [ShivModelPickerSheet]'s two behaviour modes — the default
/// global backend/model switch (Shiv chat, Nataraj) and the per-caller
/// override callbacks (`onLocalSelected`/`onCloudSelected`/
/// `currentOverrideId`) that let Gana pin a model without touching the
/// app's active backend.
void main() {
  late _MGetActiveBackend getActiveBackend;
  late _MIsCloudConnected isCloudConnected;
  late _MListCloud listCloud;
  late _MGetAvailable getAvailable;
  late _MGetDownloaded getDownloaded;
  late _MGetActiveLocal getActiveLocal;
  late _MGetActiveLlmModel getActiveLlmModel;
  late _MSetBackend setBackend;
  late _MSetModel setModel;

  setUpAll(() {
    registerFallbackValue(LlmBackendType.localGemma);
  });

  setUp(() async {
    getActiveBackend = _MGetActiveBackend();
    isCloudConnected = _MIsCloudConnected();
    listCloud = _MListCloud();
    getAvailable = _MGetAvailable();
    getDownloaded = _MGetDownloaded();
    getActiveLocal = _MGetActiveLocal();
    getActiveLlmModel = _MGetActiveLlmModel();
    setBackend = _MSetBackend();
    setModel = _MSetModel();

    await GetIt.instance.reset();
    GetIt.instance
        .registerFactory<GetActiveLlmBackendUseCase>(() => getActiveBackend);
    GetIt.instance
        .registerFactory<IsUniunCloudConnectedUseCase>(() => isCloudConnected);
    GetIt.instance.registerFactory<ListCloudLlmModelsUseCase>(() => listCloud);
    GetIt.instance
        .registerFactory<GetAvailableAIModelsUseCase>(() => getAvailable);
    GetIt.instance
        .registerFactory<GetDownloadedModelIdsUseCase>(() => getDownloaded);
    GetIt.instance.registerFactory<GetActiveAIModelUseCase>(() => getActiveLocal);
    GetIt.instance
        .registerFactory<GetActiveLlmModelUseCase>(() => getActiveLlmModel);
    GetIt.instance.registerFactory<SetActiveLlmBackendUseCase>(() => setBackend);
    GetIt.instance.registerFactory<SetActiveLlmModelUseCase>(() => setModel);

    // Common defaults: one downloaded local model, cloud connected with one
    // model on the catalog. Individual tests override where it matters.
    when(() => getActiveBackend.call())
        .thenAnswer((_) async => const Right(LlmBackendType.localGemma));
    when(() => isCloudConnected.call()).thenAnswer((_) async => true);
    when(() => listCloud.call()).thenAnswer(
        (_) async => Right([_cloud('claude-cloud-mini', 'Claude Mini')]));
    when(() => getAvailable.call())
        .thenAnswer((_) async => [_local(AIModelId.qwen25_05b)]);
    when(() => getDownloaded.call())
        .thenAnswer((_) async => {AIModelId.qwen25_05b});
    when(() => getActiveLocal.call())
        .thenAnswer((_) async => Right(_local(AIModelId.qwen25_05b)));
    when(() => getActiveLlmModel.call()).thenAnswer((_) async => const Right(null));
    when(() => setBackend.call(any()))
        .thenAnswer((_) async => const Right(unit));
    when(() => setModel.call(any())).thenAnswer((_) async => const Right(unit));
  });

  Widget host({
    bool showCloud = true,
    String? nullableOptionLabel,
    VoidCallback? onNullSelected,
    String? currentOverrideId,
    void Function(AIModelEntity)? onLocalSelected,
    void Function(LlmModelInfo)? onCloudSelected,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModelPickerSheet(
                ctx,
                showCloud: showCloud,
                nullableOptionLabel: nullableOptionLabel,
                onNullSelected: onNullSelected,
                currentOverrideId: currentOverrideId,
                onLocalSelected: onLocalSelected,
                onCloudSelected: onCloudSelected,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showCloud gating', () {
    testWidgets('showCloud=false never fetches the cloud catalog',
        (tester) async {
      await open(tester, host(showCloud: false));

      verifyNever(() => listCloud.call());
      expect(find.text('Claude Mini'), findsNothing);
    });

    testWidgets('showCloud=true (default) renders both sections',
        (tester) async {
      await open(tester, host());

      expect(find.text('Claude Mini'), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(AIModelId.qwen25_05b.displayName(l10n)), findsOneWidget);
    });
  });

  group('default behaviour (Shiv/Nataraj) — no override callbacks', () {
    testWidgets('tapping a local row switches the global backend + model',
        (tester) async {
      await open(tester, host());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(AIModelId.qwen25_05b.displayName(l10n)));
      await tester.pumpAndSettle();

      verify(() => setBackend.call(LlmBackendType.localGemma)).called(1);
      verify(() => setModel.call('qwen25_05b')).called(1);
    });

    testWidgets('tapping a cloud row switches the global backend + model',
        (tester) async {
      await open(tester, host());

      await tester.tap(find.text('Claude Mini'));
      await tester.pumpAndSettle();

      verify(() => setBackend.call(LlmBackendType.uniunCloud)).called(1);
      verify(() => setModel.call('claude-cloud-mini')).called(1);
    });
  });

  group('override callbacks (Gana per-agent pin)', () {
    testWidgets(
        'onLocalSelected fires instead of the global switch, and the sheet closes',
        (tester) async {
      AIModelEntity? picked;
      await open(
        tester,
        host(onLocalSelected: (m) => picked = m),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(AIModelId.qwen25_05b.displayName(l10n)));
      await tester.pumpAndSettle();

      expect(picked?.modelId, AIModelId.qwen25_05b);
      verifyNever(() => setBackend.call(any()));
      verifyNever(() => setModel.call(any()));
      // Sheet closed — its title is gone.
      expect(find.text(l10n.modelPickerTitle), findsNothing);
    });

    testWidgets(
        'onCloudSelected fires instead of the global switch, and the sheet closes',
        (tester) async {
      LlmModelInfo? picked;
      await open(
        tester,
        host(onCloudSelected: (m) => picked = m),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text('Claude Mini'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'claude-cloud-mini');
      verifyNever(() => setBackend.call(any()));
      verifyNever(() => setModel.call(any()));
      expect(find.text(l10n.modelPickerTitle), findsNothing);
    });

    testWidgets('currentOverrideId highlights the pinned row, not the '
        'globally-active one', (tester) async {
      // Global active backend/model is local qwen — but the override points
      // at the cloud model, which must render as the checked row instead.
      await open(
        tester,
        host(currentOverrideId: 'claude-cloud-mini'),
      );

      final checkIcon = find.byIcon(Icons.check_circle_rounded);
      expect(checkIcon, findsOneWidget);
      // The checkmark row is the cloud one — find its ancestor and confirm
      // it also contains the cloud label, not the local one.
      final row = find.ancestor(
        of: find.text('Claude Mini'),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: row, matching: checkIcon),
        findsOneWidget,
      );
    });

    testWidgets('nullableOptionLabel row calls onNullSelected and closes',
        (tester) async {
      var nullTapped = false;
      await open(
        tester,
        host(
          nullableOptionLabel: 'Use active model',
          onNullSelected: () => nullTapped = true,
          onLocalSelected: (_) {},
        ),
      );

      expect(find.text('Use active model'), findsOneWidget);
      await tester.tap(find.text('Use active model'));
      await tester.pumpAndSettle();

      expect(nullTapped, isTrue);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.modelPickerTitle), findsNothing);
    });
  });
}
