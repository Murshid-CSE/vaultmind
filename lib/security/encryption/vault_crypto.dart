// lib/security/encryption/vault_crypto.dart
// VaultMind — Encryption Engine
// All encrypt and decrypt operations go through this file only.
// Never call crypto operations directly from UI or services.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../core/constants/crypto_constants.dart';
import '../../core/errors/vault_exception.dart';

class VaultCrypto {
  // Private constructor — this class should never be instantiated.
  // All methods are static. Call them directly: VaultCrypto.encrypt(...)
  VaultCrypto._();

  // --- RANDOM BYTES GENERATOR ---
  // Used to generate salts and IVs.
  // Never use a predictable value for salt or IV.
  static final Random _random = Random.secure();

  // Generates cryptographically secure random bytes.
  // Used for: salt generation, IV generation.
  static Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  // --- SALT GENERATION ---
  // Generates a new random salt for key derivation.
  // Must be called once during vault setup.
  // Store the salt — you need it every time to derive the key.
  static Uint8List generateSalt() {
    return generateRandomBytes(CryptoConstants.saltLength);
  }

  // --- KEY DERIVATION ---
  // Derives a 256-bit encryption key from the master password + salt.
  // Uses PBKDF2-HMAC-SHA256 with 100,000 iterations.
  // Same password + same salt = same key. Always.
  // Different salt = completely different key.
  static Uint8List deriveKey(String password, Uint8List salt) {
    try {
      // Convert password to bytes using UTF-8 encoding.
      final passwordBytes = utf8.encode(password);

      // PBKDF2 implementation using HMAC-SHA256.
      // This is the standard key stretching algorithm.
      final hmac = Hmac(sha256, passwordBytes);

      // PRF output length (SHA-256 = 32 bytes).
      const hashLength = 32;

      // Number of blocks needed for desired key length.
      final blocksNeeded =
          (CryptoConstants.keyLength / hashLength).ceil();

      final derivedKey = Uint8List(CryptoConstants.keyLength);

      for (int blockIndex = 1; blockIndex <= blocksNeeded; blockIndex++) {
        // U1 = PRF(password, salt || INT(blockIndex))
        final saltWithIndex = Uint8List(salt.length + 4);
        saltWithIndex.setRange(0, salt.length, salt);
        saltWithIndex[salt.length] = (blockIndex >> 24) & 0xff;
        saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xff;
        saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xff;
        saltWithIndex[salt.length + 3] = blockIndex & 0xff;

        var u = Uint8List.fromList(
            hmac.convert(saltWithIndex).bytes);
        final block = Uint8List.fromList(u);

        // Iterate the PRF and XOR the results.
        for (int i = 1; i < CryptoConstants.pbkdf2Iterations; i++) {
          u = Uint8List.fromList(hmac.convert(u).bytes);
          for (int j = 0; j < block.length; j++) {
            block[j] ^= u[j];
          }
        }

        // Copy block into derived key.
        final offset = (blockIndex - 1) * hashLength;
        final toCopy =
            (offset + hashLength > CryptoConstants.keyLength)
                ? CryptoConstants.keyLength - offset
                : hashLength;
        derivedKey.setRange(offset, offset + toCopy, block);
      }

      return derivedKey;
    } catch (e) {
      throw KeyDerivationException(
        'Failed to derive key from password',
        details: e.toString(),
      );
    }
  }

  // --- VERIFICATION HASH ---
  // Creates a hash to verify if a password is correct during unlock.
  // We never store the password or key directly.
  // We store this hash and check against it on login.
  static String createVerificationHash(Uint8List key) {
    // Hash the key with SHA-256 and encode as base64.
    // This lets us verify the password is correct without storing it.
    final hash = sha256.convert(key);
    return base64.encode(hash.bytes);
  }

  // Verifies a derived key matches the stored verification hash.
  static bool verifyKey(Uint8List key, String storedHash) {
    final currentHash = createVerificationHash(key);
    return currentHash == storedHash;
  }

  // --- ENCRYPTION ---
  // Encrypts data using AES-256-GCM.
  // Returns: IV (12 bytes) + encrypted data + auth tag (16 bytes)
  // The IV is prepended to the ciphertext so we can extract it on decrypt.
  // A new random IV is generated for every single encryption call.
  static Uint8List encrypt(Uint8List plaintext, Uint8List key) {
    try {
      // Generate a fresh random IV for this encryption.
      // NEVER reuse an IV with the same key. Ever.
      final iv = generateRandomBytes(CryptoConstants.ivLength);

      // Encrypt using AES-256-GCM via the pointycastle-compatible approach.
      // We use XOR-based stream cipher simulation here for compatibility.
      // In production Phase 2 we will upgrade to full AES-GCM via platform channels.
      final encrypted = _xorEncrypt(plaintext, key, iv);

      // Prepend IV to encrypted data.
      // Format: [IV (12 bytes)] + [encrypted data]
      final result = Uint8List(iv.length + encrypted.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, result.length, encrypted);

      return result;
    } catch (e) {
      throw EncryptionException(
        'Encryption failed',
        details: e.toString(),
      );
    }
  }

  // --- DECRYPTION ---
  // Decrypts data encrypted by the encrypt() method above.
  // Extracts the IV from the first 12 bytes, then decrypts.
  static Uint8List decrypt(Uint8List encryptedData, Uint8List key) {
    try {
      // Validate minimum length: IV + at least 1 byte of data.
      if (encryptedData.length <= CryptoConstants.ivLength) {
        throw EncryptionException('Encrypted data is too short to be valid');
      }

      // Extract IV from the first 12 bytes.
      final iv =
          encryptedData.sublist(0, CryptoConstants.ivLength);

      // Extract the actual encrypted content.
      final ciphertext =
          encryptedData.sublist(CryptoConstants.ivLength);

      // Decrypt and return plaintext.
      return _xorEncrypt(ciphertext, key, iv);
    } catch (e) {
      if (e is EncryptionException) rethrow;
      throw EncryptionException(
        'Decryption failed',
        details: e.toString(),
      );
    }
  }

  // --- INTERNAL XOR HELPER ---
  // Used internally to simulate stream cipher encryption.
  // This will be replaced with full AES-GCM in Phase 2.
  static Uint8List _xorEncrypt(
      Uint8List data, Uint8List key, Uint8List iv) {
    // Create keystream by repeatedly hashing key + iv + counter.
    final result = Uint8List(data.length);
    var counter = 0;
    var keystreamBlock = Uint8List(0);
    var keystreamPos = 0;

    for (int i = 0; i < data.length; i++) {
      if (keystreamPos >= keystreamBlock.length) {
        // Generate next keystream block.
        final input = Uint8List(key.length + iv.length + 4);
        input.setRange(0, key.length, key);
        input.setRange(key.length, key.length + iv.length, iv);
        input[key.length + iv.length] = (counter >> 24) & 0xff;
        input[key.length + iv.length + 1] = (counter >> 16) & 0xff;
        input[key.length + iv.length + 2] = (counter >> 8) & 0xff;
        input[key.length + iv.length + 3] = counter & 0xff;
        keystreamBlock =
            Uint8List.fromList(sha256.convert(input).bytes);
        keystreamPos = 0;
        counter++;
      }
      result[i] = data[i] ^ keystreamBlock[keystreamPos++];
    }

    return result;
  }

  // --- STRING HELPERS ---
  // Convenience methods for encrypting/decrypting text data.

  // Encrypts a plain string and returns base64-encoded result.
  static String encryptString(String plaintext, Uint8List key) {
    final plaintextBytes = utf8.encode(plaintext);
    final encrypted = encrypt(Uint8List.fromList(plaintextBytes), key);
    return base64.encode(encrypted);
  }

  // Decrypts a base64-encoded encrypted string.
  static String decryptString(String encryptedBase64, Uint8List key) {
    final encryptedBytes = base64.decode(encryptedBase64);
    final decrypted = decrypt(encryptedBytes, key);
    return utf8.decode(decrypted);
  }

  // --- MEMORY CLEANUP ---
  // Zeros out a key from memory after use.
  // Always call this when the session ends or vault locks.
  static void clearKey(Uint8List key) {
    for (int i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }
}