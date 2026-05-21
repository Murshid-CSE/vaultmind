// lib/presentation/screens/auth/lock_screen.dart
// Temporary placeholder — full implementation coming next.
import 'package:flutter/material.dart';

class LockScreen extends StatelessWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Lock Screen'),
      ),
    );
  }
}