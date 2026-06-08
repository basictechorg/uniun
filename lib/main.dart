import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  await _ensureDownloaderCacheDir();
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

/// `background_downloader` (used by flutter_gemma to fetch models) stores its
/// partial-download temp files under `<Caches>/<bundleId>/` but does not create
/// that bundle-id subfolder on sandboxed Apple platforms. Without it the
/// download fails with `PathNotFoundException ... errno = 2`. Create it up front.
Future<void> _ensureDownloaderCacheDir() async {
  if (!Platform.isMacOS && !Platform.isIOS) return;
  try {
    final cacheDir = await getApplicationCacheDirectory();
    final dir = Directory(
      p.join(cacheDir.path, 'com.basictech.uniun'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  } catch (_) {
    // Best-effort: if this fails the download will surface its own error.
  }
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
