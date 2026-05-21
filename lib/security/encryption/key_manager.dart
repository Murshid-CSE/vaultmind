// lib/security/encryption/key_manager.dart
// VaultMind — Key Manager
// Holds the master key in memory during an active session.
// The key only exists in memory when the vault is unlocked.
// When the vault locks, the key is zeroed and removed immediately.

import 'dart:typed_data';
import '../../core/constants/crypto_constants.dart';
import '../../core/errors/vault_exception.dart';
import 'vault_crypto.dart';

class KeyManager {
  // Singleton pattern — only one KeyManager exists in the app.
  // This prevents multiple conflicting key states.
  static final KeyManager _instance = KeyManager._internal();
  factory KeyManager() => _instance;
  KeyManager._internal();

  // The master key held in memory.
  // Null means the vault is locked.
  // Never expose this directly outside this class.
  Uint8List? _masterKey;

  // Tracks how many failed unlock attempts have occurred.
  int _failedAttempts = 0;

  // Tracks when the lockout period started.
  DateTime? _lockoutStart;

  // --- SESSION STATE ---

  // Returns true if the vault is currently unlocked.
  // Always check this before any vault operation.
  bool get isUnlocked => _masterKey != null;

  // Returns current failed attempt count.
  int get failedAttempts => _failedAttempts;

  // --- LOCKOUT CHECK ---
  // Returns true if the user is currently locked out.
  bool get isLockedOut {
    if (_lockoutStart == null) return false;

    final elapsed =
        DateTime.now().difference(_lockoutStart!).inSeconds;

    // If lockout duration has passed, reset lockout.
    if (elapsed >= CryptoConstants.lockoutDurationSeconds) {
      _lockoutStart = null;
      _failedAttempts = 0;
      return false;
    }

    return true;
  }

  // Returns remaining lockout seconds.
  // Returns 0 if not locked out.
  int get remainingLockoutSeconds {
    if (_lockoutStart == null) return 0;

    final elapsed =
        DateTime.now().difference(_lockoutStart!).inSeconds;
    final remaining =
        CryptoConstants.lockoutDurationSeconds - elapsed;

    return remaining > 0 ? remaining : 0;
  }

  // --- UNLOCK VAULT ---
  // Call this after verifying the password is correct.
  // Stores the key in memory and resets failed attempts.
  void unlockWithKey(Uint8List key) {
    // Store a copy of the key, not a reference.
    // This ensures clearing the original doesn't affect our copy.
    _masterKey = Uint8List.fromList(key);
    _failedAttempts = 0;
    _lockoutStart = null;
  }

  // --- GET KEY ---
  // Returns the master key for encryption/decryption operations.
  // Throws if vault is locked — never returns null.
  Uint8List getKey() {
    if (_masterKey == null) {
      throw AuthException(
        'Vault is locked. Unlock the vault before accessing files.',
      );
    }
    return _masterKey!;
  }

  // --- RECORD FAILED ATTEMPT ---
  // Call this every time a wrong password is entered.
  // Triggers lockout after max attempts reached.
  void recordFailedAttempt() {
    _failedAttempts++;

    if (_failedAttempts >= CryptoConstants.maxFailedAttempts) {
      // Start lockout timer.
      _lockoutStart = DateTime.now();
    }
  }

  // --- LOCK VAULT ---
  // Zeros the key in memory and removes it.
  // Call this on: app background, auto-lock timer, manual lock.
  void lock() {
    if (_masterKey != null) {
      // Zero every byte before releasing the reference.
      // This prevents the key from lingering in memory.
      VaultCrypto.clearKey(_masterKey!);
      _masterKey = null;
    }
  }

  // --- RESET ---
  // Full reset — used when vault is being set up fresh.
  // Clears everything including failed attempts.
  void reset() {
    lock();
    _failedAttempts = 0;
    _lockoutStart = null;
  }
}