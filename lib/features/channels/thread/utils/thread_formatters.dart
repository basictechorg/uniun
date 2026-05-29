import 'package:uniun/core/utils/formatters.dart'
    show formatTimeAgo, formatShortPubkey, formatContentPreview;

/// Re-exports global formatting utilities for backward compatibility.
/// New code should import directly from lib/core/utils/formatters.dart

// Aliases for backward compatibility with existing thread code
String threadTimeAgo(DateTime dt) => formatTimeAgo(dt);
String threadShortPubkey(String pubkey) => formatShortPubkey(pubkey);
String threadContentPreview(String content) => formatContentPreview(content);
