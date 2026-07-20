import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';

/// Covers: UniunGatewayClient wire protocol — {data}/{error} envelopes,
/// error-type mapping (incl. Retry-After), SSE stream parsing across chunk
/// boundaries, and the auth/catalog endpoints.
void main() {
  UniunGatewayClient clientWith(MockClient mock) =>
      UniunGatewayClient(httpClient: mock, baseUrl: 'https://gw.test');

  http.Response ok(Object data) =>
      http.Response(jsonEncode({'data': data}), 200,
          headers: {'content-type': 'application/json'});

  http.Response err(int status, String type, String message,
          {Map<String, String> headers = const {}}) =>
      http.Response(
          jsonEncode({
            'error': {'message': message, 'type': type}
          }),
          status,
          headers: headers);

  group('auth endpoints', () {
    test('fetchChallenge posts the pubkey and unwraps {data.challenge}',
        () async {
      late Map<String, dynamic> sentBody;
      final client = clientWith(MockClient((req) async {
        expect(req.url.path, '/uniun/v1/auth/challenge');
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return ok({'challenge': '1720000000123.abcdef'});
      }));

      final challenge = await client.fetchChallenge('a' * 64);
      expect(challenge, '1720000000123.abcdef');
      expect(sentBody, {'pubkey': 'a' * 64});
    });

    test('201 Created envelopes are accepted — the live auth endpoints '
        'answer 201, not 200', () async {
      final client = clientWith(MockClient((req) async => http.Response(
          jsonEncode({
            'data': {'challenge': 'nonce64', 'expires_in': 300}
          }),
          201)));

      expect(await client.fetchChallenge('a' * 64), 'nonce64');
    });

    test('login surfaces api_key + new_account on first login', () async {
      final client = clientWith(MockClient((req) async {
        expect(req.url.path, '/uniun/v1/auth/login');
        return ok({
          'api_key': 'uk_secret',
          'key_id': 'k-1',
          'new_account': true,
          'has_profile': false,
        });
      }));

      final r = await client.login(
          pubkeyHex: 'a' * 64, challenge: 'c', signatureHex: 'f' * 128);
      expect(r.apiKey, 'uk_secret');
      expect(r.newAccount, isTrue);
    });

    test('returning login carries NO api_key — result reflects that',
        () async {
      final client = clientWith(MockClient(
          (req) async => ok({'new_account': false, 'has_profile': true})));
      final r = await client.login(
          pubkeyHex: 'a' * 64, challenge: 'c', signatureHex: 'f' * 128);
      expect(r.apiKey, isNull);
      expect(r.newAccount, isFalse);
    });
  });

  group('account + catalog', () {
    test('profile/credits send the Bearer key', () async {
      final authHeaders = <String?>[];
      final client = clientWith(MockClient((req) async {
        authHeaders.add(req.headers['Authorization']);
        return ok({'plan': 'free', 'balance': 0});
      }));

      await client.getProfile('uk_k');
      await client.getCredits('uk_k');
      expect(authHeaders, ['Bearer uk_k', 'Bearer uk_k']);
    });

    test('listModels maps category and flags paid rows', () async {
      final client = clientWith(MockClient((req) async => ok([
            {'id': 'claude-sonnet-5', 'display_name': 'Claude Sonnet 5', 'category': 'paid'},
            {'id': 'gemma4:e4b', 'display_name': 'Gemma 4 (local)', 'category': 'free'},
          ])));

      final models = await client.listModels();
      expect(models.map((m) => m.id), ['claude-sonnet-5', 'gemma4:e4b']);
      expect(models.first.isPaid, isTrue);
      expect(models.last.isPaid, isFalse);
    });

    test('revokeKey DELETEs the key id with the Bearer key', () async {
      http.Request? sent;
      final client = clientWith(MockClient((req) async {
        sent = req;
        return ok({'revoked': true});
      }));

      await client.revokeKey(apiKey: 'uk_k', keyId: 'kid-1');
      expect(sent!.method, 'DELETE');
      expect(sent!.url.path, '/uniun/v1/keys/kid-1');
      expect(sent!.headers['Authorization'], 'Bearer uk_k');
    });

    test('listPlans returns the raw plan maps', () async {
      final client = clientWith(MockClient((req) async => ok([
            {'name': 'free', 'price_paise': 0, 'models': ['gemma4:e4b']},
          ])));
      final plans = await client.listPlans();
      expect(plans.single['name'], 'free');
    });
  });

  group('error mapping', () {
    test('every wire error type maps to its enum value', () async {
      const cases = {
        'model_not_allowed': UniunGatewayErrorType.modelNotAllowed,
        'insufficient_credit': UniunGatewayErrorType.insufficientCredit,
        'invalid_api_key': UniunGatewayErrorType.unauthorized,
        'unauthorized': UniunGatewayErrorType.unauthorized,
        'challenge_invalid': UniunGatewayErrorType.unauthorized,
        'rate_limited': UniunGatewayErrorType.rateLimited,
        'invalid_request': UniunGatewayErrorType.invalidRequest,
        'upstream_error': UniunGatewayErrorType.upstreamError,
        // Upstream provider types the gateway passes through verbatim.
        'rate_limit_error': UniunGatewayErrorType.rateLimited,
        'authentication_error': UniunGatewayErrorType.unauthorized,
        'overloaded_error': UniunGatewayErrorType.upstreamError,
        'api_error': UniunGatewayErrorType.upstreamError,
      };
      for (final entry in cases.entries) {
        final client = clientWith(MockClient(
            (req) async => err(400, entry.key, 'nope')));
        try {
          await client.getProfile('uk_k');
          fail('expected throw for ${entry.key}');
        } on UniunGatewayException catch (e) {
          expect(e.type, entry.value, reason: entry.key);
          expect(e.message, 'nope');
        }
      }
    });

    test('429 carries Retry-After as a Duration', () async {
      final client = clientWith(MockClient((req) async => err(
          429, 'rate_limited', 'slow down',
          headers: {'retry-after': '17'})));
      try {
        await client.getProfile('uk_k');
        fail('expected throw');
      } on UniunGatewayException catch (e) {
        expect(e.retryAfter, const Duration(seconds: 17));
      }
    });

    test('non-JSON 5xx body is never surfaced raw — status drives the type',
        () async {
      final client = clientWith(MockClient(
          (req) async => http.Response('<html>bad gateway</html>', 502)));
      try {
        await client.getProfile('uk_k');
        fail('expected throw');
      } on UniunGatewayException catch (e) {
        expect(e.type, UniunGatewayErrorType.upstreamError);
        expect(e.message, isNot(contains('<html>')));
      }
    });

    test('connection refused becomes a network-typed exception', () async {
      final client = clientWith(MockClient(
          (req) async => throw const SocketExceptionFake()));
      expect(
        () => client.getProfile('uk_k'),
        throwsA(isA<UniunGatewayException>()
            .having((e) => e.type, 'type', UniunGatewayErrorType.network)),
      );
    });
  });

  group('streamChatCompletion (SSE)', () {
    MockClient sseMock(List<String> chunks, {int status = 200}) =>
        MockClient.streaming((req, bodyStream) async {
          return http.StreamedResponse(
            Stream.fromIterable(chunks.map(utf8.encode)),
            status,
          );
        });

    String sse(String token) => 'data: ${jsonEncode({
          'choices': [
            {'delta': {'content': token}}
          ]
        })}\n\n';

    test('yields delta tokens in order and stops at [DONE]', () async {
      final client = clientWith(sseMock([
        sse('Hel'),
        sse('lo'),
        'data: [DONE]\n\n',
        sse('NEVER'), // after DONE — must not be emitted
      ]));

      final tokens = await client.streamChatCompletion(
        apiKey: 'uk_k',
        modelId: 'claude-sonnet-5',
        messages: const [
          {'role': 'user', 'content': 'hi'}
        ],
      ).toList();
      expect(tokens, ['Hel', 'lo']);
    });

    test('an SSE event split across two network chunks reassembles',
        () async {
      final whole = sse('token');
      final client = clientWith(sseMock([
        whole.substring(0, 12),
        whole.substring(12),
        'data: [DONE]\n\n',
      ]));

      final tokens = await client.streamChatCompletion(
        apiKey: 'uk_k',
        modelId: 'm',
        messages: const [],
      ).toList();
      expect(tokens, ['token']);
    });

    test('keep-alive comments and empty deltas are skipped silently',
        () async {
      final client = clientWith(sseMock([
        ': keep-alive\n\n',
        'data: ${jsonEncode({'choices': []})}\n\n',
        sse('ok'),
        'data: [DONE]\n\n',
      ]));

      final tokens = await client.streamChatCompletion(
        apiKey: 'uk_k',
        modelId: 'm',
        messages: const [],
      ).toList();
      expect(tokens, ['ok']);
    });

    test('non-200 stream start throws the mapped gateway error', () async {
      final client = clientWith(MockClient.streaming((req, body) async =>
          http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({
                'error': {'message': 'upgrade', 'type': 'model_not_allowed'}
              }))),
              403)));

      expect(
        () => client.streamChatCompletion(
          apiKey: 'uk_k',
          modelId: 'claude-sonnet-5',
          messages: const [],
        ).toList(),
        throwsA(isA<UniunGatewayException>().having(
            (e) => e.type, 'type', UniunGatewayErrorType.modelNotAllowed)),
      );
    });
  });

  group('chatCompletion (non-stream)', () {
    test('returns the assistant message content', () async {
      final client = clientWith(MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['stream'], isFalse);
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'answer'}
                }
              ]
            }),
            200);
      }));

      final out = await client.chatCompletion(
        apiKey: 'uk_k',
        modelId: 'm',
        messages: const [
          {'role': 'user', 'content': 'q'}
        ],
      );
      expect(out, 'answer');
    });
  });
}

/// MockClient throws whatever the handler throws; a bare fake keeps the
/// network-failure test independent of dart:io.
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
}
