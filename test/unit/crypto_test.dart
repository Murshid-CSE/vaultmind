// test/unit/crypto_test.dart
// VaultMind — Crypto Foundation Tests
// Run with: flutter test test/unit/crypto_test.dart
// ALL tests must pass before moving to the next phase.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultmind/core/constants/crypto_constants.dart';
import 'package:vaultmind/core/errors/vault_exception.dart';
import 'package:vaultmind/security/encryption/vault_crypto.dart';
import 'package:vaultmind/security/encryption/key_manager.dart';

void main() {
  group('CryptoConstants', () {
    test('key length is 32 bytes (256 bits)', () {
      expect(CryptoConstants.keyLength, equals(32));
    });

    test('salt length is 16 bytes', () {
      expect(CryptoConstants.saltLength, equals(16));
    });

    test('IV length is 12 bytes', () {
      expect(CryptoConstants.ivLength, equals(12));
    });

    test('PBKDF2 iterations is at least 100000', () {
      expect(CryptoConstants.pbkdf2Iterations, greaterThanOrEqualTo(100000));
    });
  });

  group('VaultCrypto - Random Bytes', () {
    test('generates bytes of correct length', () {
      final bytes = VaultCrypto.generateRandomBytes(32);
      expect(bytes.length, equals(32));
    });

    test('two generated salts are never equal', () {
      final salt1 = VaultCrypto.generateSalt();
      final salt2 = VaultCrypto.generateSalt();
      // Salts must be unique every time.
      expect(salt1, isNot(equals(salt2)));
    });
  });

  group('VaultCrypto - Key Derivation', () {
    test('derives key of correct length', () {
      final salt = VaultCrypto.generateSalt();
      final key = VaultCrypto.deriveKey('MySecurePassword123!', salt);
      expect(key.length, equals(CryptoConstants.keyLength));
    });

    test('same password and salt always produce same key', () {
      final salt = VaultCrypto.generateSalt();
      final key1 = VaultCrypto.deriveKey('MySecurePassword123!', salt);
      final key2 = VaultCrypto.deriveKey('MySecurePassword123!', salt);
      expect(key1, equals(key2));
    });

    test('different passwords produce different keys', () {
      final salt = VaultCrypto.generateSalt();
      final key1 = VaultCrypto.deriveKey('Password1', salt);
      final key2 = VaultCrypto.deriveKey('Password2', salt);
      expect(key1, isNot(equals(key2)));
    });

    test('different salts produce different keys', () {
      final salt1 = VaultCrypto.generateSalt();
      final salt2 = VaultCrypto.generateSalt();
      final key1 = VaultCrypto.deriveKey('SamePassword', salt1);
      final key2 = VaultCrypto.deriveKey('SamePassword', salt2);
      expect(key1, isNot(equals(key2)));
    });
  });

  group('VaultCrypto - Verification Hash', () {
    test('creates verification hash from key', () {
      final salt = VaultCrypto.generateSalt();
      final key = VaultCrypto.deriveKey('TestPassword', salt);
      final hash = VaultCrypto.createVerificationHash(key);
      expect(hash, isNotEmpty);
    });

    test('correct key passes verification', () {
      final salt = VaultCrypto.generateSalt();
      final key = VaultCrypto.deriveKey('TestPassword', salt);
      final hash = VaultCrypto.createVerificationHash(key);
      expect(VaultCrypto.verifyKey(key, hash), isTrue);
    });

    test('wrong key fails verification', () {
      final salt = VaultCrypto.generateSalt();
      final key1 = VaultCrypto.deriveKey('CorrectPassword', salt);
      final key2 = VaultCrypto.deriveKey('WrongPassword', salt);
      final hash = VaultCrypto.createVerificationHash(key1);
      expect(VaultCrypto.verifyKey(key2, hash), isFalse);
    });
  });

  group('VaultCrypto - Encrypt and Decrypt', () {
    late Uint8List key;

    setUp(() {
      final salt = VaultCrypto.generateSalt();
      key = VaultCrypto.deriveKey('TestPassword123!', salt);
    });

    test('encrypt returns data longer than input', () {
      final plaintext = Uint8List.fromList(utf8.encode('Hello VaultMind'));
      final encrypted = VaultCrypto.encrypt(plaintext, key);
      // Encrypted data includes IV prefix so must be longer.
      expect(encrypted.length, greaterThan(plaintext.length));
    });

    test('decrypt returns original plaintext', () {
      final original = Uint8List.fromList(utf8.encode('Hello VaultMind'));
      final encrypted = VaultCrypto.encrypt(original, key);
      final decrypted = VaultCrypto.decrypt(encrypted, key);
      expect(decrypted, equals(original));
    });

    test('encrypting same data twice gives different results', () {
      final plaintext = Uint8List.fromList(utf8.encode('Same data'));
      final encrypted1 = VaultCrypto.encrypt(plaintext, key);
      final encrypted2 = VaultCrypto.encrypt(plaintext, key);
      // Different IVs mean different ciphertext every time.
      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('wrong key cannot decrypt', () {
      final plaintext = Uint8List.fromList(utf8.encode('Secret data'));
      final encrypted = VaultCrypto.encrypt(plaintext, key);

      final wrongSalt = VaultCrypto.generateSalt();
      final wrongKey = VaultCrypto.deriveKey('WrongPassword', wrongSalt);
      final decrypted = VaultCrypto.decrypt(encrypted, wrongKey);

      // Decryption with wrong key returns garbage, not original.
      expect(decrypted, isNot(equals(plaintext)));
    });

    test('string encrypt and decrypt round trip', () {
      const original = 'My secret note for VaultMind';
      final encrypted = VaultCrypto.encryptString(original, key);
      final decrypted = VaultCrypto.decryptString(encrypted, key);
      expect(decrypted, equals(original));
    });

    test('throws exception on too short encrypted data', () {
      final tooShort = Uint8List(4);
      expect(
        () => VaultCrypto.decrypt(tooShort, key),
        throwsA(isA<EncryptionException>()),
      );
    });
  });

  group('VaultCrypto - Memory Cleanup', () {
    test('clearKey zeros all bytes', () {
      final salt = VaultCrypto.generateSalt();
      final key = VaultCrypto.deriveKey('Password', salt);
      VaultCrypto.clearKey(key);
      // After clearing, all bytes must be zero.
      expect(key.every((byte) => byte == 0), isTrue);
    });
  });

  group('KeyManager', () {
    late KeyManager keyManager;
    late Uint8List testKey;

    setUp(() {
      keyManager = KeyManager();
      keyManager.reset();
      final salt = VaultCrypto.generateSalt();
      testKey = VaultCrypto.deriveKey('TestPassword', salt);
    });

    test('vault is locked initially', () {
      expect(keyManager.isUnlocked, isFalse);
    });

    test('vault unlocks after providing key', () {
      keyManager.unlockWithKey(testKey);
      expect(keyManager.isUnlocked, isTrue);
    });

    test('getKey returns key when unlocked', () {
      keyManager.unlockWithKey(testKey);
      final retrieved = keyManager.getKey();
      expect(retrieved, equals(testKey));
    });

    test('getKey throws when locked', () {
      expect(
        () => keyManager.getKey(),
        throwsA(isA<AuthException>()),
      );
    });

    test('lock clears the key', () {
      keyManager.unlockWithKey(testKey);
      keyManager.lock();
      expect(keyManager.isUnlocked, isFalse);
    });

    test('failed attempts increment correctly', () {
      expect(keyManager.failedAttempts, equals(0));
      keyManager.recordFailedAttempt();
      keyManager.recordFailedAttempt();
      expect(keyManager.failedAttempts, equals(2));
    });

    test('lockout triggers after max failed attempts', () {
      for (int i = 0; i < CryptoConstants.maxFailedAttempts; i++) {
        keyManager.recordFailedAttempt();
      }
      expect(keyManager.isLockedOut, isTrue);
    });

    test('reset clears everything', () {
      keyManager.unlockWithKey(testKey);
      keyManager.recordFailedAttempt();
      keyManager.reset();
      expect(keyManager.isUnlocked, isFalse);
      expect(keyManager.failedAttempts, equals(0));
    });
  });
}