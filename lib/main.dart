import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:uniun/core/router/app_router.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/services/marmot_transport_service.dart';
import 'package:uniun/gateway/gateway.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  // Preserve native splash only until Flutter renders its first frame
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await configureDependencies();
  getIt<MarmotTransportService>().start();

  // Remove native splash immediately → SplashPage takes over
  FlutterNativeSplash.remove();

  GatewayBootstrap.start();
  runApp(const UniunApp());
}

class UniunApp extends StatelessWidget {
  const UniunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UNIUN',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
