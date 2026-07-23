import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:pointycastle/export.dart' show ECDomainParameters, ECPoint;

/// Decrypts the gateway's `encrypted_api_key` (returned on every login once
/// the account has an active key, replacing the old plaintext `api_key`).
///
/// Layout (base64-decoded): `ephemeral_pubkey(33, compressed secp256k1) ||
/// nonce(12) || ciphertext+tag`. The server encrypted the raw `uk_...` key to
/// an ephemeral ECDH key pair; recovering it needs only our own Nostr
/// private key, so any device holding the identity gets the same result from
/// the same stored blob — no per-device state, no re-issuing keys.
class UniunKeyRecoveryCipher {
  const UniunKeyRecoveryCipher._();

  static const String _hkdfInfo = 'uniun-api-key-recovery-v1';
  static const int _pubkeyLength = 33;
  static const int _nonceLength = 12;

  static Future<String> decrypt(
    String encryptedApiKeyBase64,
    String privkeyHex,
  ) async {
    final blob = base64.decode(encryptedApiKeyBase64);
    final ephemeralPubkey = blob.sublist(0, _pubkeyLength);
    final nonce = blob.sublist(_pubkeyLength, _pubkeyLength + _nonceLength);
    final ciphertextAndTag = blob.sublist(_pubkeyLength + _nonceLength);

    final shared = _ecdhSharedX(privkeyHex, ephemeralPubkey);
    final symKey = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(shared),
      // RFC 5869: an omitted salt is HashLen zero bytes, not literally
      // empty — cryptography_plus's HMAC also rejects an empty key outright.
      nonce: List<int>.filled(32, 0),
      info: utf8.encode(_hkdfInfo),
    );

    final cipher = Chacha20.poly1305Aead();
    final macLength = cipher.macAlgorithm.macLength;
    final ciphertext =
        ciphertextAndTag.sublist(0, ciphertextAndTag.length - macLength);
    final mac = ciphertextAndTag.sublist(ciphertextAndTag.length - macLength);
    final plaintext = await cipher.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: symKey,
    );
    return utf8.decode(plaintext);
  }

  /// ECDH: `our_privkey * ephemeral_pubkey`, x-coordinate of the resulting
  /// point, 32 bytes big-endian — the shared secret HKDF is derived from.
  static Uint8List _ecdhSharedX(String privkeyHex, List<int> compressedPubkey) {
    final domain = ECDomainParameters('secp256k1');
    final point = domain.curve.decodePoint(compressedPubkey);
    final d = BigInt.parse(privkeyHex, radix: 16);
    final ECPoint? shared = point == null ? null : point * d;
    final x = shared?.x?.toBigInteger();
    if (x == null) {
      throw const FormatException('Invalid ephemeral pubkey in encrypted_api_key');
    }
    return _bigIntToBytes(x, 32);
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var v = value;
    final mask = BigInt.from(0xff);
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (v & mask).toInt();
      v = v >> 8;
    }
    return bytes;
  }
}
