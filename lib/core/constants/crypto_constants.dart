// lib/core/constants/crypto_constants.dart
// VaultMind — Crypto Constants
// All encryption parameters are defined here in one place.
// Never hardcode these values anywhere else in the project.

class CryptoConstants {
  // Private constructor — this class should never be instantiated.
  // It only holds constants.
  CryptoConstants._();

  // --- KEY DERIVATION (Argon2id / PBKDF2) ---

  // Length of the master encryption key in bytes.
  // 32 bytes = 256 bits = AES-256 strength.
  static const int keyLength = 32;

  // Salt length for key derivation.
  // 16 bytes = 128 bits. Must be random and unique per vault.
  static const int saltLength = 16;

  // Number of PBKDF2 iterations.
  // 100,000 iterations makes brute-force attacks expensive.
  // Never go below 100,000 for password-based key derivation.
  static const int pbkdf2Iterations = 100000;

  // --- ENCRYPTION (AES-256-GCM) ---

  // IV (Initialization Vector) length for AES-GCM.
  // 12 bytes = 96 bits. This is the standard for AES-GCM.
  // Must be unique for every single encryption operation.
  static const int ivLength = 12;

  // GCM authentication tag length in bytes.
  // 16 bytes = 128 bits. Maximum security tag size.
  static const int tagLength = 16;

  // --- SECURE STORAGE KEYS ---
  // These are the key names used in flutter_secure_storage.
  // The actual values stored are always encrypted by the OS keystore.

  static const String masterKeyStorageKey = 'vault_master_key';
  static const String saltStorageKey = 'vault_salt';
  static const String verificationHashKey = 'vault_verification_hash';
  static const String biometricEnabledKey = 'vault_biometric_enabled';

  // --- VAULT SETTINGS ---

  // Auto-lock timer in seconds.
  // Vault locks automatically after this period of inactivity.
  static const int autoLockSeconds = 60;

  // Maximum wrong password attempts before lockout.
  static const int maxFailedAttempts = 5;

  // Lockout duration in seconds after max failed attempts.
  static const int lockoutDurationSeconds = 30;
}