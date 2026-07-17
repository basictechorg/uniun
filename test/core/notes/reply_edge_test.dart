import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/core/notes/reply_edge.dart';

/// Covers: replyEdgeParentIds — the single NIP-10 rule deciding which e-tag
/// targets earn a reply-count edge (parent + mentions, never the root).
void main() {
  test('top-level note with no refs → no parents', () {
    expect(
        replyEdgeParentIds(
            replyToEventId: null, rootEventId: null, eTagRefs: const []),
        isEmpty);
  });

  test('direct reply: parent counted, thread root excluded', () {
    expect(
      replyEdgeParentIds(
        replyToEventId: 'parent',
        rootEventId: 'root',
        eTagRefs: const ['root', 'parent'],
      ),
      {'parent'},
    );
  });

  test('mentions earn edges alongside the reply parent', () {
    expect(
      replyEdgeParentIds(
        replyToEventId: 'parent',
        rootEventId: 'root',
        eTagRefs: const ['root', 'parent', 'mention-a', 'mention-b'],
      ),
      {'parent', 'mention-a', 'mention-b'},
    );
  });

  test('reply directly to the root: replyToEventId still counts once', () {
    expect(
      replyEdgeParentIds(
        replyToEventId: 'root',
        rootEventId: 'root',
        eTagRefs: const ['root'],
      ),
      {'root'},
    );
  });

  test('pure mention note (no threading fields) counts every ref', () {
    expect(
      replyEdgeParentIds(
        replyToEventId: null,
        rootEventId: null,
        eTagRefs: const ['a', 'b'],
      ),
      {'a', 'b'},
    );
  });

  test('duplicate refs collapse into the set', () {
    expect(
      replyEdgeParentIds(
        replyToEventId: 'parent',
        rootEventId: null,
        eTagRefs: const ['parent', 'm', 'm'],
      ),
      {'parent', 'm'},
    );
  });
}
