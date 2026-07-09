import 'dart:convert';

import 'package:nostr_core_dart/nostr.dart';

/// Structurally parsed and cryptographically verified Nostr event.
class VerifiedNostrEvent {
  const VerifiedNostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
    required this.raw,
  });

  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() => raw;

  String toCanonicalJson() => jsonEncode(raw);
}

class NostrEventVerifier {
  const NostrEventVerifier();

  VerifiedNostrEvent? verify(Map<String, dynamic> raw) {
    try {
      final id = raw['id'];
      final pubkey = raw['pubkey'];
      final createdAt = raw['created_at'];
      final kind = raw['kind'];
      final tags = raw['tags'];
      final content = raw['content'];
      final sig = raw['sig'];
      if (id is! String ||
          pubkey is! String ||
          createdAt is! int ||
          kind is! int ||
          tags is! List ||
          content is! String ||
          sig is! String) {
        return null;
      }

      final normalizedTags = <List<String>>[];
      for (final tag in tags) {
        if (tag is! List) return null;
        final normalizedTag = <String>[];
        for (final value in tag) {
          if (value is! String) return null;
          normalizedTag.add(value);
        }
        normalizedTags.add(normalizedTag);
      }

      final normalizedRaw = <String, dynamic>{
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': normalizedTags,
        'content': content,
        'sig': sig,
      };
      final event = Event.fromJson(normalizedRaw, verify: false);
      if (!event.isValid()) return null;

      return VerifiedNostrEvent(
        id: id,
        pubkey: pubkey,
        createdAt: createdAt,
        kind: kind,
        tags: normalizedTags,
        content: content,
        sig: sig,
        raw: normalizedRaw,
      );
    } catch (_) {
      return null;
    }
  }
}
