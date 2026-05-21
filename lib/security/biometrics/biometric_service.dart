// lib/security/biometrics/biometric_service.dart
// VaultMind — Biometric Service
// Handles fingerprint and face unlock using device hardware.
// Never stores biometric data — uses OS-level authentication only.

import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/constants/crypto_constants.dart';
import '../../core/errors/vault_exception.dart';
import '../encryption/vault_crypto.dart';
import '../encryption/key_manager.dart';

class BiometricService {
  // Singleton pattern.
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  // local_auth handles all biometric operations.
  // It uses Android BiometricPrompt and iOS LocalAuthentication.
  final _localAuth = LocalAuthentication();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  final _keyManager = KeyManager();

  // --- CHECK AVAILABILITY ---
  // Returns true if device supports biometric authentication.
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if device hardware supports biometrics.
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // Returns list of available biometric types on this device.
  // Example: [BiometricType.fingerprint, BiometricType.face]
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // --- CHECK IF BIOMETRIC IS ENABLED FOR VAULT ---
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(
        key: CryptoConstants.biometricEnabledKey,
      );
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  // --- ENABLE BIOMETRIC ---
  // Called when user enables biometric unlock in settings.
  // Stores the master key protected by biometric authentication.
  // The key is stored in secure storage — biometric gates access to it.
  Future<void> enableBiometric(Uint8List masterKey) async {
    try {
      // Verify biometric is available before enabling.
      if (!await isBiometricAvailable()) {
        throw AuthException(
          'Biometric authentication is not available on this device.',
        );
      }

      // Authenticate once to confirm user consent.
      final authenticated = await _authenticate(
        reason: 'Confirm your identity to enable biometric unlock',
      );

      if (!authenticated) {
        throw AuthException('Biometric authentication cancelled.');
      }

      // Store the master key in secure storage.
      // flutter_secure_storage on Android uses EncryptedSharedPreferences
      // which is backed by Android Keystore hardware.
      await _storage.write(
        key: CryptoConstants.masterKeyStorageKey,
        value: base64.encode(masterKey),
      );

      // Mark biometric as enabled.
      await _storage.write(
        key: CryptoConstants.biometricEnabledKey,
        value: 'true',
      );
    } catch (e) {
      if (e is VaultException) rethrow;
      throw AuthException(
        'Failed to enable biometric',
        details: e.toString(),
      );
    }
  }

  // --- DISABLE BIOMETRIC ---
  // Removes the stored key and disables biometric unlock.
  Future<void> disableBiometric() async {
    try {
      await _storage.delete(key: CryptoConstants.masterKeyStorageKey);
      await _storage.write(
        key: CryptoConstants.biometricEnabledKey,
        value: 'false',
      );
    } catch (e) {
      throw AuthException(
        'Failed to disable biometric',
        details: e.toString(),
      );
    }
  }

  // --- UNLOCK WITH BIOMETRIC ---
  // Called when user wants to unlock vault using fingerprint or face.
  // Authenticates user, retrieves stored key, unlocks vault.
  Future<void> unlockWithBiometric() async {
    try {
      // Check biometric is enabled.
      if (!await isBiometricEnabled()) {
        throw AuthException('Biometric unlock is not enabled.');
      }

      // Trigger OS biometric prompt.
      // This shows the fingerprint/face dialog to the user.
      final authenticated = await _authenticate(
        reason: 'Unlock VaultMind',
      );

      if (!authenticated) {
        throw AuthException('Biometric authentication failed or cancelled.');
      }

      // Retrieve the stored master key from secure storage.
      final keyBase64 = await _storage.read(
        key: CryptoConstants.masterKeyStorageKey,
      );

      if (keyBase64 == null) {
        throw AuthException(
          'Biometric key not found. Please use your master password.',
        );
      }

      // Decode and load the key into KeyManager.
      final masterKey = Uint8List.fromList(base64.decode(keyBase64));
      _keyManager.unlockWithKey(masterKey);

      // Clear local key variable.
      VaultCrypto.clearKey(masterKey);
    } catch (e) {
      if (e is VaultException) rethrow;
      throw AuthException(
        'Biometric unlock failed',
        details: e.toString(),
      );
    }
  }

  // --- PRIVATE AUTHENTICATE ---
  // Triggers the OS biometric prompt and returns result.
  // --- PRIVATE AUTHENTICATE ---
  // Triggers the OS biometric prompt and returns result.
  Future<bool> _authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (e) {
      return false;
    }
  }
}