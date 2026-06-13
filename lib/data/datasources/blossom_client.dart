import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

/// Blob descriptor returned by Blossom (BUD-01).
class BlobDescriptor {
  const BlobDescriptor({
    required this.url,
    required this.sha256,
    required this.size,
    required this.mime,
    this.uploaded,
  });

  final String url;
  final String sha256;
  final int size;
  final String mime;
  final DateTime? uploaded;

  factory BlobDescriptor.fromJson(Map<String, dynamic> json) {
    final uploadedSec = json['uploaded'];
    return BlobDescriptor(
      url: json['url'] as String,
      sha256: json['sha256'] as String,
      size: (json['size'] as num).toInt(),
      mime: (json['type'] as String?) ?? 'application/octet-stream',
      uploaded: uploadedSec is num
          ? DateTime.fromMillisecondsSinceEpoch(uploadedSec.toInt() * 1000)
          : null,
    );
  }
}

class BlossomException implements Exception {
  BlossomException(this.statusCode, this.reason);
  final int statusCode;
  final String reason;
  @override
  String toString() => 'BlossomException($statusCode): $reason';
}

/// HTTP client for our backend's Blossom (NIP-B7) endpoints. Signs Kind
/// 24242 auth events for actions that need authentication (upload, list,
/// delete) and sends them as `Authorization: Nostr <base64>`.
///
/// `HEAD /<sha256>` and `GET /<sha256>` are unauthenticated by default —
/// content is public on a public Blossom server.
@lazySingleton
class BlossomClient {
  BlossomClient();

  final http.Client _http = http.Client();

  /// Per-request timeouts. Without these the http.Client waits forever for
  /// a slow / unreachable backend, which surfaces as a stuck UI (the
  /// composer's attach button disappears and never comes back).
  static const Duration _shortTimeout = Duration(seconds: 10);
  static const Duration _uploadTimeout = Duration(seconds: 60);
  static const Duration _downloadTimeout = Duration(seconds: 60);

  /// Returns true if the server already has this blob.
  Future<bool> head(String serverUrl, String sha256) async {
    final res = await _http
        .head(_blobUri(serverUrl, sha256))
        .timeout(_shortTimeout);
    return res.statusCode == 200;
  }

  Future<BlobDescriptor> upload({
    required String serverUrl,
    required Uint8List bytes,
    required String mime,
    required String sha256,
    required UserSigningKeys keys,
  }) async {
    final auth = _buildAuth(
      action: 'upload',
      sha256: sha256,
      keys: keys,
      content: 'Upload',
    );
    final res = await _http
        .put(
          Uri.parse('$serverUrl/upload'),
          headers: {
            'Authorization': 'Nostr $auth',
            'Content-Type': mime,
            'Content-Length': bytes.length.toString(),
          },
          body: bytes,
        )
        .timeout(_uploadTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) {
      // 413 = nginx (or any reverse proxy) rejected the request before it
      // reached the Blossom handler. The HTML body is unhelpful — surface a
      // short reason so the snackbar isn't a wall of HTML.
      final reason = res.statusCode == 413
          ? 'Server rejected upload: file too large for the relay'
          : res.headers['x-reason'] ?? res.body;
      throw BlossomException(res.statusCode, reason);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return BlobDescriptor.fromJson(body);
  }

  Future<Uint8List> download(String serverUrl, String sha256) async {
    final res = await _http
        .get(_blobUri(serverUrl, sha256))
        .timeout(_downloadTimeout);
    if (res.statusCode != 200) {
      throw BlossomException(
        res.statusCode,
        res.headers['x-reason'] ?? 'download failed',
      );
    }
    return res.bodyBytes;
  }

  Future<List<BlobDescriptor>> list({
    required String serverUrl,
    required String pubkeyHex,
    required UserSigningKeys keys,
  }) async {
    final auth = _buildAuth(
      action: 'list',
      sha256: null,
      keys: keys,
      content: 'List blobs',
    );
    final res = await _http.get(
      Uri.parse('$serverUrl/list/$pubkeyHex'),
      headers: {'Authorization': 'Nostr $auth'},
    ).timeout(_shortTimeout);
    if (res.statusCode != 200) {
      throw BlossomException(
        res.statusCode,
        res.headers['x-reason'] ?? 'list failed',
      );
    }
    final raw = jsonDecode(res.body);
    if (raw is! List) {
      throw BlossomException(res.statusCode, 'list did not return an array');
    }
    return raw
        .cast<Map<String, dynamic>>()
        .map(BlobDescriptor.fromJson)
        .toList();
  }

  Future<void> deleteRemote({
    required String serverUrl,
    required String sha256,
    required UserSigningKeys keys,
  }) async {
    final auth = _buildAuth(
      action: 'delete',
      sha256: sha256,
      keys: keys,
      content: 'Delete',
    );
    final res = await _http.delete(
      _blobUri(serverUrl, sha256),
      headers: {'Authorization': 'Nostr $auth'},
    ).timeout(_shortTimeout);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw BlossomException(
        res.statusCode,
        res.headers['x-reason'] ?? 'delete failed',
      );
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────

  Uri _blobUri(String serverUrl, String sha256) =>
      Uri.parse('$serverUrl/$sha256');

  /// Builds a signed Kind 24242 event, JSON-encodes it, base64-encodes the
  /// JSON. Auth window is 5 minutes — long enough for slow uploads, short
  /// enough that a leaked token is mostly useless.
  String _buildAuth({
    required String action,
    required String? sha256,
    required UserSigningKeys keys,
    required String content,
  }) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tags = <List<String>>[
      ['t', action],
      if (sha256 != null) ['x', sha256],
      ['expiration', (nowSec + 300).toString()],
    ];
    final event = Event.from(
      kind: 24242,
      tags: tags,
      content: content,
      privkey: keys.privkeyHex,
      createdAt: nowSec,
    );
    final payload = jsonEncode({
      'id': event.id,
      'pubkey': event.pubkey,
      'created_at': event.createdAt,
      'kind': event.kind,
      'tags': tags,
      'content': event.content,
      'sig': event.sig,
    });
    return base64.encode(utf8.encode(payload));
  }
}
