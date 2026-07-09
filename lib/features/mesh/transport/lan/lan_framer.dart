import 'dart:typed_data';

import '../../mesh_constants.dart';

/// Hard cap on a single framed message (guards against a bogus/huge length on the
/// wire). Mesh app messages (events, sync batches) are well under this. Alias of
/// the shared [kMeshMaxMessageBytes].
const int kLanMaxMessageBytes = kMeshMaxMessageBytes;

class LanFrameException implements Exception {
  LanFrameException(this.message);
  final String message;
  @override
  String toString() => 'LanFrameException: $message';
}

/// Prefixes [message] with a 4-byte big-endian length. A TCP socket is a byte
/// stream with no message boundaries, so every `MeshLink` message is length-framed.
Uint8List lanFrame(Uint8List message) {
  final out = Uint8List(4 + message.length);
  ByteData.view(out.buffer).setUint32(0, message.length, Endian.big);
  out.setRange(4, out.length, message);
  return out;
}

/// Stateful decoder for the length-prefix framing. Feed it raw socket chunks (any
/// size, split anywhere) via [add]; it yields each complete message exactly once,
/// buffering partial headers/payloads across chunks. Throws [LanFrameException] if
/// a declared length exceeds [kLanMaxMessageBytes].
///
/// Chunks are buffered in a list and consumed byte-exactly by [_take], so a large
/// message arriving as many small chunks costs O(total bytes) — not the O(n²) of
/// re-concatenating a growing buffer on every chunk (the classic accumulate-by-
/// concat trap a hostile peer could amplify by dribbling a big frame one byte at
/// a time).
class LanFrameDecoder {
  final List<Uint8List> _chunks = [];
  int _pending = 0; // total bytes currently buffered across [_chunks]
  int _frameLen = -1; // payload length, once the 4-byte header is read (else -1)

  Iterable<Uint8List> add(Uint8List chunk) sync* {
    if (chunk.isEmpty) return;
    _chunks.add(chunk);
    _pending += chunk.length;

    while (true) {
      if (_frameLen < 0) {
        if (_pending < 4) return; // header not fully arrived yet
        final header = _take(4);
        _frameLen =
            ByteData.sublistView(header).getUint32(0, Endian.big);
        if (_frameLen > kLanMaxMessageBytes) {
          throw LanFrameException('frame length $_frameLen exceeds cap');
        }
      }
      if (_pending < _frameLen) return; // payload not fully arrived yet
      yield _take(_frameLen);
      _frameLen = -1;
    }
  }

  /// Removes and returns the first [n] buffered bytes, advancing across chunk
  /// boundaries. Each byte is copied exactly once; a partially consumed chunk is
  /// replaced by a zero-copy view of its tail.
  Uint8List _take(int n) {
    final out = Uint8List(n);
    var written = 0;
    while (written < n) {
      final head = _chunks.first;
      final take = n - written;
      if (head.length <= take) {
        out.setRange(written, written + head.length, head);
        written += head.length;
        _chunks.removeAt(0);
      } else {
        out.setRange(written, written + take, head);
        _chunks[0] = Uint8List.sublistView(head, take);
        written += take;
      }
    }
    _pending -= n;
    return out;
  }
}
