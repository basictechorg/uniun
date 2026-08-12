import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/gateway/inbound/event_parser.dart';

/// Covers: EventParser's pure tag-walking helpers — eTagIds' malformed-tag
/// filtering (non-list, too-short, non-'e', null/empty id) and no-tags
/// fallback, firstTagValue's first-match-wins and not-found cases, and the
/// unix-seconds→DateTime conversion.
void main() {
  group('eTagIds', () {
    test('extracts every well-formed e-tag id', () {
      final ids = EventParser.eTagIds({
        'tags': [
          ['e', 'id-1'],
          ['e', 'id-2', 'relay', 'root'],
        ],
      });
      expect(ids, ['id-1', 'id-2']);
    });

    test('skips non-list tags, too-short tags, non-e tags, and null/empty '
        'ids', () {
      final ids = EventParser.eTagIds({
        'tags': [
          'not-a-list',
          ['e'],
          ['p', 'pubkey'],
          ['e', null],
          ['e', ''],
          ['e', 'good-id'],
        ],
      });
      expect(ids, ['good-id']);
    });

    test('a missing tags key yields an empty list', () {
      expect(EventParser.eTagIds({}), isEmpty);
    });
  });

  group('firstTagValue', () {
    test('returns the value of the first match', () {
      final v = EventParser.firstTagValue({
        'tags': [
          ['d', 'first'],
          ['d', 'second'],
        ],
      }, 'd');
      expect(v, 'first');
    });

    test('returns null when no tag matches', () {
      final v = EventParser.firstTagValue({
        'tags': [
          ['e', 'x'],
        ],
      }, 'd');
      expect(v, isNull);
    });

    test('skips malformed (non-list or too-short) tags while scanning', () {
      final v = EventParser.firstTagValue({
        'tags': [
          'not-a-list',
          ['d'],
          ['d', 'value'],
        ],
      }, 'd');
      expect(v, 'value');
    });

    test('a missing tags key yields null', () {
      expect(EventParser.firstTagValue({}, 'd'), isNull);
    });
  });

  test('dateTimeFromSec converts unix seconds to a UTC-epoch-relative '
      'DateTime', () {
    final dt = EventParser.dateTimeFromSec(1_700_000_000);
    expect(dt, DateTime.fromMillisecondsSinceEpoch(1_700_000_000 * 1000));
  });
}
