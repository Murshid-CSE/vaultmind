// lib/security/auth/session_manager.dart
// VaultMind — Session Manager
// Handles auto-lock timer and app lifecycle locking.
// When the app goes to background or timer expires, vault locks automatically.

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/constants/crypto_constants.dart';
import 'auth_service.dart';

class SessionManager with WidgetsBindingObserver {
  // Singleton pattern.
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final _authService = AuthService();

  // Auto-lock timer.
  Timer? _autoLockTimer;

  // Callback triggered when vault locks.
  // UI listens to this to navigate to lock screen.
  VoidCallback? onLock;

  // --- INITIALIZE ---
  // Call this once in main.dart after app starts.
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  // --- DISPOSE ---
  // Call this when app is permanently closed.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
  }

  // --- START SESSION ---
  // Call this after successful unlock.
  // Starts the auto-lock countdown.
  void startSession() {
    _cancelTimer();
    _startAutoLockTimer();
  }

  // --- RESET TIMER ---
  // Call this on any user interaction to reset the inactivity timer.
  // This prevents locking while user is actively using the app.
  void resetTimer() {
    if (_authService.isUnlocked) {
      _cancelTimer();
      _startAutoLockTimer();
    }
  }

  // --- MANUAL LOCK ---
  // Call when user taps the lock button manually.
  void lockNow() {
    _cancelTimer();
    _authService.lockVault();
    onLock?.call();
  }

  // --- APP LIFECYCLE HANDLER ---
  // Flutter calls this automatically when app state changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      // App went to background — lock immediately.
      // This prevents someone from seeing vault content
      // if they grab the phone while app is open.
        lockNow();
        break;

      case AppLifecycleState.resumed:
      // App came back to foreground.
      // Do NOT auto-unlock here — user must authenticate again.
        break;

      case AppLifecycleState.inactive:
      // App is partially obscured (e.g. notification shade).
      // Lock as a precaution.
        lockNow();
        break;

      case AppLifecycleState.detached:
      // App is being terminated.
        lockNow();
        break;

      case AppLifecycleState.hidden:
        lockNow();
        break;
    }
  }

  // --- PRIVATE HELPERS ---

  void _startAutoLockTimer() {
    _autoLockTimer = Timer(
      Duration(seconds: CryptoConstants.autoLockSeconds),
      () {
        // Timer expired — lock the vault.
        _authService.lockVault();
        onLock?.call();
      },
    );
  }

  void _cancelTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
  }
}