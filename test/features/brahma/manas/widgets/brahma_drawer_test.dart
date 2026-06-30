import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/features/brahma/manas/bloc/manas_list_bloc.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/features/brahma/manas/widgets/brahma_drawer.dart';
import 'package:uniun/l10n/app_localizations.dart';

class _FakeListBloc extends MockBloc<ManasListEvent, ManasListState>
    implements ManasListBloc {}

class _FakeGraphBloc extends MockBloc<GraphEvent, GraphState>
    implements GraphBloc {}

ManasEntity _manas(String id, {String? icon}) => ManasEntity(
      manasId: id,
      name: id,
      iconName: icon,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Behavioral widget tests for [BrahmaDrawer]. The drawer's
/// `BlocProvider.create` calls `getIt<ManasListBloc>()`, so we register a
/// MockBloc with controlled state in `getIt` before each test instead of
/// going through `BlocProvider.value` (which wouldn't override the inner
/// `create:`).
void main() {
  late _FakeListBloc listBloc;
  late _FakeGraphBloc graphBloc;

  setUpAll(() {
    registerFallbackValue(const LoadGraphEvent());
    registerFallbackValue(const ManasListLoadEvent());
  });

  setUp(() async {
    listBloc = _FakeListBloc();
    graphBloc = _FakeGraphBloc();
    when(() => graphBloc.state).thenReturn(const GraphState());
    // Each call to getIt<ManasListBloc>() returns a FRESH instance — the
    // `BlocProvider.create` inside the drawer closes the bloc on dispose,
    // so reusing the same MockBloc across pumps would crash on second
    // open. Returning `listBloc` directly works because we only mount once
    // per test.
    await GetIt.instance.reset();
    GetIt.instance.registerFactory<ManasListBloc>(() => listBloc);
  });

  Widget host(String? activeManasId) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: BlocProvider<GraphBloc>.value(
        value: graphBloc,
        child: Scaffold(
          drawer: BrahmaDrawer(activeManasId: activeManasId),
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('loading state shows a spinner, not the list', (tester) async {
    when(() => listBloc.state).thenReturn(
      const ManasListState(status: ManasListStatus.loading),
    );
    await tester.pumpWidget(host(null));
    // pumpAndSettle would wait forever on the spinner's animation; pump
    // just enough frames to open the drawer.
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DropLoadingIndicator), findsOneWidget);
  });

  testWidgets('loaded state renders a tile per Manas', (tester) async {
    when(() => listBloc.state).thenReturn(
      ManasListState(
        status: ManasListStatus.loaded,
        manases: [_manas('Work'), _manas('Research'), _manas('Personal')],
      ),
    );
    await tester.pumpWidget(host(null));
    await openDrawer(tester);

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('tapping a Manas tile fires LoadGraphEvent(manasId: that.id)', (tester) async {
    when(() => listBloc.state).thenReturn(
      ManasListState(
        status: ManasListStatus.loaded,
        manases: [_manas('Work')],
      ),
    );
    await tester.pumpWidget(host(null));
    await openDrawer(tester);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    final captured = verify(() => graphBloc.add(captureAny())).captured;
    final loadEvents = captured.whereType<LoadGraphEvent>().toList();
    expect(loadEvents, isNotEmpty);
    expect(loadEvents.last.manasId, 'Work');
  });

  testWidgets('empty list still renders the drawer chrome (no crash)', (tester) async {
    when(() => listBloc.state).thenReturn(
      const ManasListState(status: ManasListStatus.loaded, manases: []),
    );
    await tester.pumpWidget(host(null));
    await openDrawer(tester);
    // Drawer rendered without throwing — no specific Manas text expected.
    expect(find.byType(Drawer), findsOneWidget);
  });
}
