import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/features/home/pages/home_page.dart';
import 'package:uniun/features/onboarding/pages/about_you_page.dart';
import 'package:uniun/features/thread/pages/thread_page.dart';
import 'package:uniun/features/shiv/model_select/pages/ai_model_selection_page.dart';
import 'package:uniun/features/settings/pages/edit_profile_page.dart';
import 'package:uniun/features/settings/pages/privacy_policy_page.dart';
import 'package:uniun/features/settings/pages/settings_page.dart';
import 'package:uniun/features/onboarding/pages/import_identity_page.dart';
import 'package:uniun/features/onboarding/pages/splash_page.dart';
import 'package:uniun/features/onboarding/pages/welcome_page.dart';
import 'package:uniun/features/onboarding/pages/your_identity_keys_page.dart';
import 'package:uniun/features/channels/create/pages/create_channel_page.dart';
import 'package:uniun/features/channels/join/pages/join_channel_page.dart';
import 'package:uniun/features/private_channels/create/pages/create_private_channel_page.dart';
import 'package:uniun/features/private_channels/join/pages/join_private_channel_page.dart';
import 'package:uniun/features/private_channels/detail/pages/private_channel_detail_page.dart';
import 'package:uniun/features/channels/feed/pages/channel_feed_page.dart';
import 'package:uniun/features/saved_notes/pages/saved_notes_page.dart';
import 'package:uniun/features/dm/create/pages/create_dm_page.dart';
import 'package:uniun/features/dm/chat/pages/dm_chat_page.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/features/brahma/graph/pages/graph_page.dart';
import 'package:uniun/features/brahma/graph/pages/graph_compose_page.dart';
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
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashPage(),
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
            return ThreadPage(noteId: args.noteId, hasUnread: args.hasUnread, savedOnly: args.savedOnly);
          }
          return ThreadPage(noteId: args as String);
        },
        AppRoutes.createChannel: (_) => const CreateChannelPage(),
        AppRoutes.joinChannel: (_) => const JoinChannelPage(),
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
