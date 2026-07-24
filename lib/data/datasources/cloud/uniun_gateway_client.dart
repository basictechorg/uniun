import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

/// Error taxonomy of the UNIUN inference gateway (`{ error: { type } }`).
enum UniunGatewayErrorType {
  unauthorized,
  insufficientCredit,
  modelNotAllowed,
  rateLimited,
  invalidRequest,
  upstreamError,
  network,
  unknown;

  static UniunGatewayErrorType fromWire(String? type) {
    switch (type) {
      case 'unauthorized':
      case 'invalid_api_key':
      case 'challenge_invalid':
      case 'bad_signature':
        return UniunGatewayErrorType.unauthorized;
      case 'qr_session_invalid':
        return UniunGatewayErrorType.invalidRequest;
      case 'insufficient_credit':
        return UniunGatewayErrorType.insufficientCredit;
      case 'model_not_allowed':
        return UniunGatewayErrorType.modelNotAllowed;
      // The gateway passes upstream provider errors through verbatim, so
      // Anthropic/OpenAI wire types arrive alongside our own.
      case 'rate_limited':
      case 'rate_limit_error':
        return UniunGatewayErrorType.rateLimited;
      case 'authentication_error':
        return UniunGatewayErrorType.unauthorized;
      case 'overloaded_error':
      case 'api_error':
        return UniunGatewayErrorType.upstreamError;
      case 'invalid_request':
      case 'invalid_request_error':
        return UniunGatewayErrorType.invalidRequest;
      case 'upstream_error':
        return UniunGatewayErrorType.upstreamError;
      default:
        return UniunGatewayErrorType.unknown;
    }
  }
}

/// Typed failure from the gateway. [retryAfter] is set on rate limits so
/// callers can back off per the server's `Retry-After` header.
class UniunGatewayException implements Exception {
  const UniunGatewayException(
    this.type,
    this.message, {
    this.statusCode,
    this.retryAfter,
  });

  final UniunGatewayErrorType type;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

/// One model row from `GET /uniun/v1/models`. `category` is `free` (open to
/// all, no charge — the on-device tier) or `paid` (flat under a covering
/// subscription plan, otherwise per-token from the credit balance).
class UniunModel {
  const UniunModel({
    required this.id,
    required this.displayName,
    required this.category,
  });

  final String id;
  final String displayName;
  final String category;

  bool get isPaid => category == 'paid';
}

/// Result of a login. [encryptedApiKey] is a base64 blob present whenever
/// the account holds an active key — decrypt with
/// [UniunKeyRecoveryCipher.decrypt] using the caller's own Nostr private
/// key; the same stored blob decrypts identically on any device, so there
/// is no per-device state. Null only when the account has zero active keys
/// — recover via [UniunGatewayClient.recoverKey].
class UniunLoginResult {
  const UniunLoginResult({
    required this.newAccount,
    required this.hasProfile,
    this.encryptedApiKey,
    this.keyId,
  });

  final bool newAccount;

  /// True once the account has a `username` set on the gateway. False is
  /// the cue to push the app's own profile up via [UniunGatewayClient.updateProfile].
  final bool hasProfile;
  final String? encryptedApiKey;
  final String? keyId;
}

/// Thin HTTP client for the UNIUN inference gateway (`api.uniun.in`).
///
/// Protocol only — no key storage, no signing, no backend selection. Auth
/// orchestration (signing, decryption, key storage) lives in
/// `UniunRepositoryImpl`, the only class that composes this client with
/// identity logic. `/uniun/v1/*` returns `{data}` / `{error:{message,type}}`;
/// `/v1/chat/completions` is OpenAI-compatible with SSE streaming.
@lazySingleton
class UniunGatewayClient {
  UniunGatewayClient({
    @ignoreParam http.Client? httpClient,
    @ignoreParam String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _base = Uri.parse(baseUrl ?? defaultBaseUrl);

  static const String defaultBaseUrl = 'https://api.uniun.in';

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// First-token timeout for streaming; generous because a cold upstream
  /// model can take a while before the first SSE chunk.
  static const Duration _streamConnectTimeout = Duration(seconds: 60);

  final http.Client _http;
  final Uri _base;

  Uri _u(String path) => _base.replace(path: path);

  Map<String, String> _headers({String? apiKey}) => {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      };

  // ── Auth ──────────────────────────────────────────────────────────────

  /// Issues a fresh login challenge for [pubkeyHex]. Stateless with a 60 s
  /// TTL — sign and redeem immediately, never cache or reuse.
  Future<String> fetchChallenge(String pubkeyHex) async {
    final data = await _postJson('/uniun/v1/auth/challenge', {
      'pubkey': pubkeyHex,
    });
    return data['challenge'] as String;
  }

  /// Redeems a signed challenge. First login auto-creates the account.
  Future<UniunLoginResult> login({
    required String pubkeyHex,
    required String challenge,
    required String signatureHex,
  }) async {
    final data = await _postJson('/uniun/v1/auth/login', {
      'pubkey': pubkeyHex,
      'challenge': challenge,
      'signature': signatureHex,
    });
    return UniunLoginResult(
      newAccount: data['new_account'] == true,
      hasProfile: data['has_profile'] == true,
      encryptedApiKey: data['encrypted_api_key'] as String?,
      keyId: data['key_id'] as String?,
    );
  }

  /// Mints a fresh key when the account has zero active ones (login came
  /// back with no [UniunLoginResult.encryptedApiKey] to decrypt) — same
  /// challenge/sign flow as [login], redeemed against `/uniun/v1/keys`
  /// instead. The key comes back raw: this is a live authenticated mint,
  /// not the stored-at-signup blob, so there's nothing to decrypt.
  Future<({String apiKey, String? keyId})> recoverKey({
    required String pubkeyHex,
    required String challenge,
    required String signatureHex,
    String name = 'recovered',
  }) async {
    final data = await _postJson('/uniun/v1/keys', {
      'name': name,
      'pubkey': pubkeyHex,
      'challenge': challenge,
      'signature': signatureHex,
    });
    return (
      apiKey: data['api_key'] as String,
      keyId: data['key_id'] as String?,
    );
  }

  /// Revokes an API key by its gateway id. Requires a live key as Bearer.
  /// Used on disconnect so the account can mint again on the next login.
  ///
  /// The server 409s (`last_active_key`) when this is the account's only
  /// active key — [confirm] re-sends the request with `?confirm=true` to
  /// go through anyway, after the caller has warned the user.
  Future<void> revokeKey({
    required String apiKey,
    required String keyId,
    bool confirm = false,
  }) async {
    var uri = _u('/uniun/v1/keys/$keyId');
    if (confirm) {
      uri = uri.replace(queryParameters: {'confirm': 'true'});
    }
    final http.Response res;
    try {
      res = await _http
          .delete(uri, headers: _headers(apiKey: apiKey))
          .timeout(_requestTimeout);
    } catch (e) {
      throw UniunGatewayException(
          UniunGatewayErrorType.network, 'Network error: $e');
    }
    _dataFrom(res);
  }

  /// Approves a browser's QR-login session, per `docs/frontend/QR-LOGIN.md`
  /// on the gateway: signs and hands over this device's own key so the
  /// browser can sign in as the same account. [rawKey] is the phone's own
  /// already-decrypted `uk_...` key — omit only when this device's account
  /// currently has zero active keys, in which case the server mints a fresh
  /// one for the browser instead.
  ///
  /// Throws [UniunGatewayException] `invalidRequest` (410, wire type
  /// `qr_session_invalid`) when the session is unknown, expired, or already
  /// used, and `unauthorized` (401, wire type `bad_signature`) on a bad sig.
  Future<void> approveQrSession({
    required String sessionId,
    required String pubkeyHex,
    required String signatureHex,
    String? rawKey,
  }) async {
    await _postJson('/uniun/v1/auth/qr/session/$sessionId/approve', {
      'pubkey': pubkeyHex,
      'signature': signatureHex,
      if (rawKey != null) 'raw_key': rawKey,
    });
  }

  // ── Account ───────────────────────────────────────────────────────────

  /// `{plan, username, pubkey, …}` for the key's account.
  Future<Map<String, dynamic>> getProfile(String apiKey) =>
      _getJson('/uniun/v1/profile', apiKey: apiKey);

  /// Sets the account's `username`/`email` on the gateway (at least one
  /// required). Used to push the app's own known profile up once, on first
  /// connect — never overwrites unprompted after that. Throws
  /// [UniunGatewayException] `invalidRequest` on bad format and
  /// `unknown`(409) on a taken username; callers treat both as best-effort.
  Future<void> updateProfile({
    required String apiKey,
    String? username,
    String? email,
  }) async {
    final http.Response res;
    try {
      res = await _http
          .put(
            _u('/uniun/v1/profile'),
            headers: _headers(apiKey: apiKey),
            body: jsonEncode({
              if (username != null) 'username': username,
              if (email != null) 'email': email,
            }),
          )
          .timeout(_requestTimeout);
    } catch (e) {
      throw UniunGatewayException(
          UniunGatewayErrorType.network, 'Network error: $e');
    }
    _dataFrom(res);
  }

  /// `{plan, balance}`.
  Future<Map<String, dynamic>> getCredits(String apiKey) =>
      _getJson('/uniun/v1/credits', apiKey: apiKey);

  /// Public plan catalog: `[{name, kind, price_paise, models, …}]`.
  Future<List<Map<String, dynamic>>> listPlans() async {
    final data = await _getList('/uniun/v1/plans');
    return data.cast<Map<String, dynamic>>();
  }

  /// Public model catalog.
  Future<List<UniunModel>> listModels() async {
    final data = await _getList('/uniun/v1/models');
    return [
      for (final m in data.cast<Map<String, dynamic>>())
        UniunModel(
          id: m['id'] as String,
          displayName: (m['display_name'] as String?) ?? m['id'] as String,
          category: (m['category'] as String?) ?? '',
        ),
    ];
  }

  // ── Inference ─────────────────────────────────────────────────────────

  /// Streams completion tokens for an OpenAI-shaped `messages` list.
  Stream<String> streamChatCompletion({
    required String apiKey,
    required String modelId,
    required List<Map<String, String>> messages,
    int? maxTokens,
  }) async* {
    final req = http.Request('POST', _u('/v1/chat/completions'))
      ..headers.addAll(_headers(apiKey: apiKey))
      ..body = jsonEncode({
        'model': modelId,
        'messages': messages,
        'stream': true,
        if (maxTokens != null) 'max_tokens': maxTokens,
      });

    final res = await _http.send(req).timeout(_streamConnectTimeout);
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      throw _errorFrom(res.statusCode, body, res.headers);
    }

    // SSE: lines of `data: {json}`, terminated by `data: [DONE]`.
    var buffer = '';
    await for (final chunk in res.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final nl = buffer.indexOf('\n');
        if (nl < 0) break;
        final line = buffer.substring(0, nl).trimRight();
        buffer = buffer.substring(nl + 1);
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') return;
        final token = _deltaContent(payload);
        if (token != null && token.isNotEmpty) yield token;
      }
    }
  }

  /// Non-streaming completion; returns the assistant message content.
  Future<String?> chatCompletion({
    required String apiKey,
    required String modelId,
    required List<Map<String, String>> messages,
    int? maxTokens,
  }) async {
    final res = await _http
        .post(
          _u('/v1/chat/completions'),
          headers: _headers(apiKey: apiKey),
          body: jsonEncode({
            'model': modelId,
            'messages': messages,
            'stream': false,
            if (maxTokens != null) 'max_tokens': maxTokens,
          }),
        )
        .timeout(_streamConnectTimeout);
    if (res.statusCode != 200) {
      throw _errorFrom(res.statusCode, res.body, res.headers);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) return null;
    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    return message?['content'] as String?;
  }

  static String? _deltaContent(String sseJson) {
    try {
      final map = jsonDecode(sseJson) as Map<String, dynamic>;
      final choices = map['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) return null;
      final delta =
          (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
      return delta?['content'] as String?;
    } catch (_) {
      return null; // keep-alives / malformed chunks are skipped, not fatal
    }
  }

  // ── Plumbing ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? apiKey,
  }) async {
    final http.Response res;
    try {
      res = await _http
          .post(_u(path), headers: _headers(apiKey: apiKey), body: jsonEncode(body))
          .timeout(_requestTimeout);
    } catch (e) {
      throw UniunGatewayException(
          UniunGatewayErrorType.network, 'Network error: $e');
    }
    return _dataFrom(res);
  }

  Future<Map<String, dynamic>> _getJson(String path, {String? apiKey}) async {
    final http.Response res;
    try {
      res = await _http
          .get(_u(path), headers: _headers(apiKey: apiKey))
          .timeout(_requestTimeout);
    } catch (e) {
      throw UniunGatewayException(
          UniunGatewayErrorType.network, 'Network error: $e');
    }
    return _dataFrom(res);
  }

  Future<List<dynamic>> _getList(String path, {String? apiKey}) async {
    final http.Response res;
    try {
      res = await _http
          .get(_u(path), headers: _headers(apiKey: apiKey))
          .timeout(_requestTimeout);
    } catch (e) {
      throw UniunGatewayException(
          UniunGatewayErrorType.network, 'Network error: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _errorFrom(res.statusCode, res.body, res.headers);
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['data'] as List<dynamic>;
  }

  Map<String, dynamic> _dataFrom(http.Response res) {
    // Auth endpoints answer 201 Created — accept the whole 2xx class.
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _errorFrom(res.statusCode, res.body, res.headers);
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
  }

  UniunGatewayException _errorFrom(
    int status,
    String body,
    Map<String, String> headers,
  ) {
    String message = 'Request failed (HTTP $status)';
    String? wireType;
    try {
      final err = (jsonDecode(body) as Map<String, dynamic>)['error']
          as Map<String, dynamic>?;
      if (err != null) {
        message = (err['message'] as String?) ?? message;
        wireType = err['type'] as String?;
      }
    } catch (_) {
      // 5xx bodies may not be JSON — never surface them raw.
    }
    var type = UniunGatewayErrorType.fromWire(wireType);
    if (type == UniunGatewayErrorType.unknown) {
      type = switch (status) {
        401 => UniunGatewayErrorType.unauthorized,
        402 => UniunGatewayErrorType.insufficientCredit,
        403 => UniunGatewayErrorType.modelNotAllowed,
        429 => UniunGatewayErrorType.rateLimited,
        400 || 410 => UniunGatewayErrorType.invalidRequest,
        502 || 503 => UniunGatewayErrorType.upstreamError,
        _ => UniunGatewayErrorType.unknown,
      };
    }
    Duration? retryAfter;
    final ra = headers['retry-after'];
    if (ra != null) {
      final secs = int.tryParse(ra);
      if (secs != null) retryAfter = Duration(seconds: secs);
    }
    return UniunGatewayException(type, message,
        statusCode: status, retryAfter: retryAfter);
  }
}
