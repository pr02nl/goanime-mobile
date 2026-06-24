import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:flutter/widgets.dart';

void main() async {
  // Chave privada que está no app
  const privB64 = '6xTZbO1u1tZp27eEMKPntloU3Aw889evKi8KHCTWSdk=';

  final seed = base64Decode(privB64);
  if (seed.length != 32) {
    debugPrint('ERRO: seed tem ${seed.length} bytes, esperado 32');
    exit(1);
  }

  final ed25519 = Ed25519();
  final keyPair = await ed25519.newKeyPairFromSeed(seed);
  final publicKey = await keyPair.extractPublicKey();
  final publicKeyBytes = publicKey.bytes;

  debugPrint('=== Chave pública RAW (base64) ===');
  debugPrint(base64Encode(publicKeyBytes));
  debugPrint('');

  // SPKI DER (formato OpenSSL)
  final spkiPrefix = [
    0x30,
    0x2a,
    0x30,
    0x05,
    0x06,
    0x03,
    0x2b,
    0x65,
    0x70,
    0x03,
    0x21,
    0x00,
  ];
  final spki = Uint8List(spkiPrefix.length + 32)
    ..setRange(0, spkiPrefix.length, spkiPrefix)
    ..setRange(spkiPrefix.length, spkiPrefix.length + 32, publicKeyBytes);

  debugPrint('=== Chave pública SPKI DER (hex) ===');
  debugPrint(spki.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
}
