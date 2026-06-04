import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/home/pages/home_page.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/onboarding/pages/about_you_page.dart';
import 'package:uniun/features/thread/pages/thread_page.dart';
import 'package:uniun/features/shiv/model_select/pages/ai_model_selection_page.dart';
import 'package:uniun/features/settings/pages/edit_profile_page.dart';
import 'package:uniun/features/settings/pages/privacy_policy_page.dart';
import 'package:uniun/features/settings/pages/settings_page.dart';
import 'package:uniun/features/onboarding/pages/import_identity_page.dart';
import 'package:uniun/features/onboarding/pages/welcome_page.dart';
import 'package:uniun/features/onboarding/pages/your_identity_keys_page.dart';
import 'package:uniun/features/channels/create/pages/create_channel_page.dart';
import 'package:uniun/features/channels/entry/pages/channel_entry_page.dart';
import 'package:uniun/features/channels/join/pages/join_channel_page.dart';
import 'package:uniun/features/private_channels/create/pages/create_private_channel_page.dart';
import 'package:uniun/features/private_channels/entry/pages/private_channel_entry_page.dart';
import 'package:uniun/features/private_channels/join/pages/join_private_channel_page.dart';
import 'package:uniun/features/private_channels/detail/pages/private_channel_detail_page.dart';
import 'package:uniun/features/channels/feed/pages/channel_feed_page.dart';
import 'package:uniun/features/saved_notes/pages/saved_notes_page.dart';
import 'package:uniun/features/dm/create/pages/create_dm_page.dart';
import 'package:uniun/features/dm/chat/pages/dm_chat_page.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/qr/uniun_qr_scanner_page.dart';
import 'package:uniun/features/brahma/graph/pages/graph_page.dart';
import 'package:uniun/features/brahma/graph/pages/graph_compose_page.dart';
import 'package:uniun/domain/services/marmot_transport_service.dart';
import 'package:uniun/gateway/gateway.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await FlutterGemma.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await configureDependencies();
  getIt<MarmotTransportService>().start();

  // Auth check runs under the native splash — no Flutter-side splash needed.
  final activeUser = await getIt<GetActiveUserUseCase>().call();
  final initialRoute = activeUser.fold(
    (_) => AppRoutes.welcome,
    (_) => AppRoutes.home,
  );

  FlutterNativeSplash.remove();

  GatewayBootstrap.start();
  runApp(UniunApp(initialRoute: initialRoute));
}

class UniunApp extends StatelessWidget {
  const UniunApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      initialRoute: initialRoute,
      routes: {
        AppRoutes.welcome: (_) => const WelcomePage(),
        AppRoutes.importIdentity: (_) => const ImportIdentityPage(),
        AppRoutes.yourIdentityKeys: (_) => const YourIdentityKeysPage(),
        AppRoutes.aboutYou: (_) => const AboutYouPage(),
        AppRoutes.home: (_) => const HomePage(),
        AppRoutes.settings: (_) => const SettingsPage(),
        AppRoutes.editProfile: (_) => const EditProfilePage(),
        AppRoutes.privacyPolicy: (_) => const PrivacyPolicyPage(),
        AppRoutes.thread: (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments;
          if (args is ThreadRouteArgs) {
            return ThreadPage(noteId: args.noteId, savedOnly: args.savedOnly);
          }
          return ThreadPage(noteId: args as String);
        },
        AppRoutes.channelEntry: (_) => const ChannelEntryPage(),
        AppRoutes.createChannel: (_) => const CreateChannelPage(),
        AppRoutes.joinChannel: (_) => const JoinChannelPage(),
        AppRoutes.privateChannelEntry: (_) => const PrivateChannelEntryPage(),
        AppRoutes.createPrivateChannel: (_) => const CreatePrivateChannelPage(),
        AppRoutes.joinPrivateChannel: (_) => const JoinPrivateChannelPage(),
        AppRoutes.privateChannelDetail: (ctx) => PrivateChannelDetailPage(
              groupId: ModalRoute.of(ctx)!.settings.arguments as String,
            ),
        AppRoutes.channelDetail: (ctx) => ChannelFeedPage(
          channelId: ModalRoute.of(ctx)!.settings.arguments as String,
        ),
        AppRoutes.aiModelSelection: (_) => const AIModelSelectionPage(),
        AppRoutes.savedNotes: (_) => const SavedNotesPage(),
        AppRoutes.createDm: (_) => const CreateDmPage(),
        AppRoutes.chatDm: (_) => const DmChatPage(),
        AppRoutes.scanQr: (_) => const UniunQrScannerPage(),
        AppRoutes.brahmaCreate: (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map?;
          return GraphComposePage(
            initialDraftId: args?['draftId'] as String?,
            autoPublish: args?['autoPublish'] as bool? ?? false,
          );
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.graph) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => const GraphPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        }
        return null;
      },
    );
  }
}
