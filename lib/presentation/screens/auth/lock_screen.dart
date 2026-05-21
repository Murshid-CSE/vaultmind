// lib/presentation/screens/auth/lock_screen.dart
// VaultMind — Lock Screen
// Shown every time the vault is locked.
// User unlocks with master password or biometrics.

import 'package:flutter/material.dart';
import '../../../security/auth/auth_service.dart';
import '../../../security/biometrics/biometric_service.dart';
import '../../../core/errors/vault_exception.dart';
import '../vault/vault_home_screen.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _biometricService = BiometricService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // Check if biometric unlock is available and enabled.
  Future<void> _checkBiometric() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available && enabled;
      });
    }

    // Auto-trigger biometric prompt if available.
    if (_biometricAvailable) {
      _unlockWithBiometric();
    }
  }

  // Unlock using master password.
  Future<void> _unlockWithPassword() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your master password.';
        _isLoading = false;
      });
      return;
    }

    try {
      await _authService.loginWithPassword(password);
      _passwordController.clear();
      _navigateToVault();
    } on LockoutException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unlock failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Unlock using biometric.
  Future<void> _unlockWithBiometric() async {
    try {
      await _biometricService.unlockWithBiometric();
      _navigateToVault();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      // Biometric failed silently — user can still use password.
    }
  }

  // Navigate to vault home after successful unlock.
  void _navigateToVault() {
    widget.onUnlocked();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const VaultHomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 64),

              // Lock icon.
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'VaultMind',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter your master password to unlock',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),

              const SizedBox(height: 48),

              // Password field.
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onSubmitted: (_) => _unlockWithPassword(),
                decoration: InputDecoration(
                  hintText: 'Master password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Error message.
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Unlock button.
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _unlockWithPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Unlock Vault',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // Biometric button — only shown if available.
              if (_biometricAvailable) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _unlockWithBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use Biometric'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}