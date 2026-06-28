import 'package:uniun/common/locator.dart';
import 'package:uniun/domain/usecases/get_relays_usecase.dart';
import 'package:uniun/domain/usecases/save_relay_usecase.dart';

/// Universal-link domain. Serves `/.well-known/assetlinks.json` (Android) and
/// `/.well-known/apple-app-site-association` (iOS) — see `deeplink/README.md`
/// for the files and hosting steps. Keep in sync with the native config
/// (AndroidManifest intent-filter host + iOS Associated Domains entitlement).
const String kDeepLinkHost = 'www.uniun.in';
const String kDeepLinkScheme = 'https';

/// Path segments shared by the public https links and the in-app GoRouter
/// routes (single source of truth for both).
const String kGroupSegment = 'group';
const String kPrivateSegment = 'private';
const String kUserSegment = 'user';

/// Legacy public-group segment. Links shared as `/channel/<id>` before the
/// channel→group rename are still honoured — the router redirects them to
/// [kGroupSegment]. Keep until old links are no longer in circulation.
const String kLegacyGroupSegment = 'channel';

/// Builds shareable `https://` universal links for each entity. The path
/// doubles as the in-app route path, so a tapped link resolves through the
/// same GoRouter parser. Relay hints ride along as query params (mirroring
/// [UniunQrPayload]) so the receiver can act on the entity.
abstract class DeepLink {
  static Uri group(
    String groupId, {
    String? name,
    List<String> relays = const [],
  }) =>
      _build(kGroupSegment, groupId, name: name, relays: relays);

  static Uri privateGroup(
    String groupId, {
    String? name,
    List<String> relays = const [],
  }) =>
      _build(kPrivateSegment, groupId, name: name, relays: relays);

  static Uri user(String npub, {List<String> relays = const []}) =>
      _build(kUserSegment, npub, relays: relays);

  static Uri _build(
    String segment,
    String id, {
    String? name,
    List<String> relays = const [],
  }) {
    final query = <String, dynamic>{
      // Marks a link as arriving from outside the app. The router's redirects
      // use this to run their auth/relay/membership work only for external
      // links — in-app navigation (no `dl`) skips straight to the page.
      kDeepLinkFlag: '1',
      if (name != null && name.isNotEmpty) 'name': name,
      if (relays.isNotEmpty) 'relays': relays,
    };
    return Uri(
      scheme: kDeepLinkScheme,
      host: kDeepLinkHost,
      pathSegments: [segment, id],
      queryParameters: query,
    );
  }
}

/// Query-param key flagging a URL as an external deep link (see [DeepLink._build]).
const String kDeepLinkFlag = 'dl';

/// Persists any relay hints we don't already have, so the Gateway connects
/// them and the deep-linked entity can sync. Idempotent — skips known relays.
/// Mirrors the QR scanner's relay-ensure behaviour.
Future<void> ensureRelays(List<String> relays) async {
  if (relays.isEmpty) return;
  final existing = await getIt<GetRelaysUseCase>().call();
  final known = existing.fold(
    (_) => <String>{},
    (list) => list.map((r) => r.url).toSet(),
  );
  final save = getIt<SaveRelayUseCase>();
  for (final url in relays) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || known.contains(trimmed)) continue;
    await save.call(trimmed);
  }
}
