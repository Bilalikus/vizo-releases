import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

/// AES-256 End-to-End Encryption service.
///
/// Provides key generation, encryption and decryption using
/// AES-256-CBC with PKCS7 padding.
class EncryptionService {
  /// Generate a cryptographically secure AES-256 key (32 bytes).
  static String generateKey() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Generate a random 16-byte IV.
  static String generateIV() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Derive a 256-bit key from a passphrase using PBKDF2.
  static String deriveKey(String passphrase, String salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(
      Uint8List.fromList(utf8.encode(salt)),
      10000,
      32,
    ));
    final key = derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
    return base64Url.encode(key);
  }

  /// Encrypt plaintext using AES-256-CBC.
  ///
  /// Returns a combined string: `iv:ciphertext` (both base64).
  static String encryptText(String plaintext, String keyBase64) {
    if (plaintext.isEmpty) return '';

    final keyBytes = base64Url.decode(keyBase64);
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt ciphertext from the `iv:ciphertext` format.
  static String decryptText(String encryptedData, String keyBase64) {
    if (encryptedData.isEmpty) return '';

    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return '';

      final keyBytes = base64Url.decode(keyBase64);
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return '';
    }
  }

  /// Encrypt a Map of data (serialises to JSON first).
  static String encryptMap(Map<String, dynamic> data, String keyBase64) {
    final json = jsonEncode(data);
    return encryptText(json, keyBase64);
  }

  /// Decrypt to a Map from the `iv:ciphertext` format.
  static Map<String, dynamic>? decryptMap(
      String encryptedData, String keyBase64) {
    final json = decryptText(encryptedData, keyBase64);
    if (json.isEmpty) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
