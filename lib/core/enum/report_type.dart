/// NIP-56 report categories (https://github.com/nostr-protocol/nips/blob/master/56.md).
///
/// The serialized name (`.name`) is exactly the wire value placed in the report
/// type slot of `e` / `p` tags inside a Kind-1984 event. Do not rename without
/// updating the cross-client contract.
enum ReportType {
  nudity,
  malware,
  profanity,
  illegal,
  spam,
  impersonation,
  other,
}
