// lib/core/errors/vault_exception.dart
// VaultMind — Custom Exceptions
// All vault-specific errors are defined here.
// Using custom exceptions makes debugging clear and precise.

// Base exception for all VaultMind errors.
// Every other exception extends this.
class VaultException implements Exception {
  final String message;
  final String? details;

  const VaultException(this.message, {this.details});

  @override
  String toString() {
    if (details != null) {
      return 'VaultException: $message\nDetails: $details';
    }
    return 'VaultException: $message';
  }
}

// Thrown when encryption or decryption fails.
class EncryptionException extends VaultException {
  const EncryptionException(super.message, {super.details});
}

// Thrown when key derivation fails.
class KeyDerivationException extends VaultException {
  const KeyDerivationException(super.message, {super.details});
}

// Thrown when authentication fails.
// Example: wrong password, biometric failure.
class AuthException extends VaultException {
  const AuthException(super.message, {super.details});
}

// Thrown when max failed attempts is exceeded.
class LockoutException extends VaultException {
  final int remainingSeconds;

  const LockoutException(super.message, {required this.remainingSeconds});

  @override
  String toString() {
    return 'LockoutException: $message\nTry again in $remainingSeconds seconds';
  }
}

// Thrown when a file operation fails.
class FileVaultException extends VaultException {
  const FileVaultException(super.message, {super.details});
}

// Thrown when database operations fail.
class DatabaseException extends VaultException {
  const DatabaseException(super.message, {super.details});
}