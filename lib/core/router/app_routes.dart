/// go_router route **names**. Used with `context.goNamed` / `context.pushNamed`.
///
/// The actual URL paths live in [appRouter] (`app_router.dart`). The three
/// deep-linkable routes (channelDetail, privateChannelDetail, chatDm) map to
/// clean path patterns that double as universal-link paths — see [DeepLink].
abstract class AppRoutes {
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const importIdentity = 'importIdentity';
  static const yourIdentityKeys = 'yourIdentityKeys';
  static const aboutYou = 'aboutYou';
  static const howItWorks = 'howItWorks';
  static const home = 'home';
  static const settings = 'settings';
  static const editProfile = 'editProfile';
  static const privacyPolicy = 'privacyPolicy';
  static const followedNoteDetail = 'followedNoteDetail';
  static const thread = 'thread';
  static const aiModelSelection = 'aiModelSelection';
  static const channelEntry = 'channelEntry';
  static const createChannel = 'createChannel';
  static const joinChannel = 'joinChannel';
  static const savedNotes = 'savedNotes';
  static const blockedUsers = 'blockedUsers';
  static const channelDetail = 'channelDetail';
  static const graph = 'graph';
  static const createDm = 'createDm';
  static const chatDm = 'chatDm';
  static const brahmaCreate = 'brahmaCreate';
  static const privateChannelEntry = 'privateChannelEntry';
  static const createPrivateChannel = 'createPrivateChannel';
  static const joinPrivateChannel = 'joinPrivateChannel';
  static const privateChannelDetail = 'privateChannelDetail';
  static const scanQr = 'scanQr';
  static const userProfile = 'userProfile';
  static const receiveShare = 'receiveShare';
  static const mediaGallery = 'mediaGallery';
  static const mediaDetail = 'mediaDetail';
  static const brahmaManasForm = 'brahmaManasForm';
  static const shivGanaForm = 'shivGanaForm';
  static const shivGanaDetail = 'shivGanaDetail';
  static const shivNataraj = 'shivNataraj';
}
