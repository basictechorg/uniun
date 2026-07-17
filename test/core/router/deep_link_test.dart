import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/router/deep_link.dart';

/// Covers: DeepLink universal-link builders — host/scheme/path shape, the
/// external `dl` flag, and optional name/relay hint query params.
void main() {
  test('group link carries segment, id, dl flag, name and relay hints', () {
    final uri = DeepLink.group('g-1',
        name: 'General', relays: ['wss://a', 'wss://b']);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.uniun.in');
    expect(uri.pathSegments, [kGroupSegment, 'g-1']);
    expect(uri.queryParameters[kDeepLinkFlag], '1');
    expect(uri.queryParameters['name'], 'General');
    expect(uri.queryParametersAll['relays'], ['wss://a', 'wss://b']);
  });

  test('private group link uses the private segment', () {
    final uri = DeepLink.privateGroup('pg-1');
    expect(uri.pathSegments, [kPrivateSegment, 'pg-1']);
    expect(uri.queryParameters[kDeepLinkFlag], '1');
  });

  test('user link uses the user segment with the npub as the id', () {
    final uri = DeepLink.user('npub1xyz');
    expect(uri.pathSegments, [kUserSegment, 'npub1xyz']);
  });

  test('empty name and empty relays are omitted from the query', () {
    final uri = DeepLink.group('g-1', name: '', relays: const []);
    expect(uri.queryParameters.containsKey('name'), isFalse);
    expect(uri.queryParameters.containsKey('relays'), isFalse);
    // The dl flag is always present — router redirects key off it.
    expect(uri.queryParameters, {kDeepLinkFlag: '1'});
  });

  test('unicode group names survive the URI encode/parse round trip', () {
    final uri = DeepLink.group('g-1', name: '🐉 समूह');
    expect(Uri.parse(uri.toString()).queryParameters['name'], '🐉 समूह');
  });
}
