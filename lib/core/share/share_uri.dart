import 'package:uniun/core/router/deep_link.dart';

/// External share URL for a note.
///
/// In-app sharing rides on NIP-18 `q` tags (see [ShareRepository] +
/// [EmbeddedNoteCard]), so no `nostr:note1...` URI is embedded in event
/// content. This helper only produces the OS-level deep link used by
/// `share_plus` and QR cards.
abstract class ShareUri {
  /// Public HTTPS deep link for sharing outside the app:
  /// `https://www.uniun.in/note/<hex>?dl=1`. Routed by the OS to the
  /// installed app via App Links / Universal Links; falls through to the
  /// website homepage otherwise.
  static Uri externalUrlFor(String eventHex) => Uri(
        scheme: kDeepLinkScheme,
        host: kDeepLinkHost,
        pathSegments: [kNoteSegment, eventHex],
        queryParameters: const {kDeepLinkFlag: '1'},
      );
}
