// lib/presentation/screens/auth/onboarding_screen.dart
// Temporary placeholder — full implementation coming next.
import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onSetupComplete;
  const OnboardingScreen({super.key, required this.onSetupComplete});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Onboarding'),
      ),
    );
  }
}