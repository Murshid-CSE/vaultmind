// lib/security/auth/auth_service.dart
// VaultMind — Authentication Service
// Handles vault setup, login, biometric auth, and session management.
// This is the single entry point for all authentication logic.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/crypto_constants.dart';
import '../../core/errors/vault_exception.dart';
import '../encryption/vault_crypto.dart';
import '../encryption/key_manager.dart';

class AuthService {
  // Singleton pattern — one auth service for the entire app.
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // flutter_secure_storage uses OS keystore (Android Keystore / iOS Keychain).
  // Data stored here is encrypted by the operating system itself.
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  final _keyManager = KeyManager();

  // --- VAULT SETUP STATE ---

  // Returns true if vault has been set up before.
  // Checks if a salt exists in secure storage.
  Future<bool> isVaultInitialized() async {
    try {
      final salt = await _storage.read(
        key: CryptoConstants.saltStorageKey,
      );
      return salt != null;
    } catch (e) {
      return false;
    }
  }

  // --- SETUP VAULT ---
  // Called once when user sets up VaultMind for the first time.
  // Generates salt, derives key, stores verification hash.
  // Never stores the password or the key directly.
  Future<void> setupVault(String masterPassword) async {
    try {
      // Validate password strength before setup.
      _validatePasswordStrength(masterPassword);

      // Generate a fresh random salt.
      final salt = VaultCrypto.generateSalt();

      // Derive the master key from password + salt.
      final masterKey = VaultCrypto.deriveKey(masterPassword, salt);

      // Create a verification hash to check password on future logins.
      final verificationHash =
          VaultCrypto.createVerificationHash(masterKey);

      // Store salt as base64 in secure storage.
      await _storage.write(
        key: CryptoConstants.saltStorageKey,
        value: base64.encode(salt),
      );

      // Store verification hash.
      await _storage.write(
        key: CryptoConstants.verificationHashKey,
        value: verificationHash,
      );

      // Unlock the vault immediately after setup.
      _keyManager.unlockWithKey(masterKey);

      // Clear the derived key variable — key is now in KeyManager only.
      VaultCrypto.clearKey(masterKey);
    } catch (e) {
      if (e is VaultException) rethrow;
      throw AuthException(
        'Vault setup failed',
        details: e.toString(),
      );
    }
  }

  // --- LOGIN WITH PASSWORD ---
  // Called every time user unlocks vault with master password.
  Future<void> loginWithPassword(String masterPassword) async {
    try {
      // Check if user is locked out from too many failed attempts.
      if (_keyManager.isLockedOut) {
        throw LockoutException(
          'Too many failed attempts. Try again later.',
          remainingSeconds: _keyManager.remainingLockoutSeconds,
        );
      }

      // Read stored salt from secure storage.
      final saltBase64 = await _storage.read(
        key: CryptoConstants.saltStorageKey,
      );

      if (saltBase64 == null) {
        throw AuthException('Vault is not initialized.');
      }

      final salt = base64.decode(saltBase64);

      // Derive key from entered password + stored salt.
      final derivedKey = VaultCrypto.deriveKey(
        masterPassword,
        Uint8List.fromList(salt),
      );

      // Read stored verification hash.
      final storedHash = await _storage.read(
        key: CryptoConstants.verificationHashKey,
      );

      if (storedHash == null) {
        throw AuthException('Vault data is corrupted.');
      }

      // Verify the derived key matches what was set during setup.
      final isCorrect = VaultCrypto.verifyKey(derivedKey, storedHash);

      if (!isCorrect) {
        // Wrong password — record the failed attempt.
        _keyManager.recordFailedAttempt();
        VaultCrypto.clearKey(derivedKey);

        final remaining = CryptoConstants.maxFailedAttempts -
            _keyManager.failedAttempts;

        if (_keyManager.isLockedOut) {
          throw LockoutException(
            'Too many failed attempts.',
            remainingSeconds: _keyManager.remainingLockoutSeconds,
          );
        }

        throw AuthException(
          'Incorrect password. $remaining attempts remaining.',
        );
      }

      // Password is correct — unlock the vault.
      _keyManager.unlockWithKey(derivedKey);

      // Clear local key variable immediately.
      VaultCrypto.clearKey(derivedKey);
    } catch (e) {
      if (e is VaultException) rethrow;
      throw AuthException(
        'Login failed',
        details: e.toString(),
      );
    }
  }

  // --- LOCK VAULT ---
  // Call on: app background, auto-lock timer, manual lock.
  void lockVault() {
    _keyManager.lock();
  }

  // --- SESSION STATE ---
  bool get isUnlocked => _keyManager.isUnlocked;
  bool get isLockedOut => _keyManager.isLockedOut;
  int get remainingLockoutSeconds => _keyManager.remainingLockoutSeconds;
  int get failedAttempts => _keyManager.failedAttempts;

  // --- CHANGE PASSWORD ---
  // Re-encrypts verification hash with new password.
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      // Verify current password first.
      await loginWithPassword(currentPassword);

      // Setup with new password.
      await setupVault(newPassword);
    } catch (e) {
      if (e is VaultException) rethrow;
      throw AuthException('Password change failed', details: e.toString());
    }
  }

  // --- PASSWORD VALIDATION ---
  // Enforces minimum password strength.
  void _validatePasswordStrength(String password) {
    if (password.length < 8) {
      throw AuthException(
        'Password must be at least 8 characters long.',
      );
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw AuthException(
        'Password must contain at least one number.',
      );
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw AuthException(
        'Password must contain at least one uppercase letter.',
      );
    }
  }
}