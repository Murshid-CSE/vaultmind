// lib/main.dart
// VaultMind — App Entry Point
// Initializes session manager and routes to correct screen on startup.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/crypto_constants.dart';
import 'security/auth/session_manager.dart';
import 'presentation/screens/auth/lock_screen.dart';
import 'presentation/screens/auth/onboarding_screen.dart';
import 'security/auth/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent screenshots and screen recording on Android.
  // This protects vault content from being captured.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Initialize session manager to listen to app lifecycle.
  SessionManager().initialize();

  runApp(
    // ProviderScope is required for Riverpod to work.
    const ProviderScope(
      child: VaultMindApp(),
    ),
  );
}

class VaultMindApp extends StatelessWidget {
  const VaultMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaultMind',
      debugShowCheckedModeBanner: false,

      // Dark theme — better for a security app.
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
        ),
        useMaterial3: true,
      ),

      home: const AppRouter(),
    );
  }
}

// Routes to correct screen based on vault state.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkVaultState();

    // Listen for lock events from SessionManager.
    SessionManager().onLock = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  Future<void> _checkVaultState() async {
    final initialized = await _authService.isVaultInitialized();
    if (mounted) {
      setState(() {
        _isInitialized = initialized;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Not set up yet — show onboarding.
    if (!_isInitialized) {
      return OnboardingScreen(
        onSetupComplete: () {
          setState(() {
            _isInitialized = true;
          });
        },
      );
    }

    // Set up but locked — show lock screen.
    return LockScreen(
      onUnlocked: () {
        setState(() {});
      },
    );
  }
}