// lib/presentation/screens/vault/vault_home_screen.dart
// VaultMind — Vault Home Screen
// Main screen after unlock. Shows all vault sections.

import 'package:flutter/material.dart';
import '../../../security/auth/session_manager.dart';

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  int _selectedIndex = 0;

  // Main sections of the vault.
  final List<_VaultSection> _sections = [
    _VaultSection(
      label: 'Files',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      color: const Color(0xFF6C63FF),
    ),
    _VaultSection(
      label: 'Notes',
      icon: Icons.note_outlined,
      activeIcon: Icons.note,
      color: const Color(0xFF43B89C),
    ),
    _VaultSection(
      label: 'Passwords',
      icon: Icons.key_outlined,
      activeIcon: Icons.key,
      color: const Color(0xFFFF6584),
    ),
    _VaultSection(
      label: 'Search',
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      color: const Color(0xFFFFAA00),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Reset session timer on screen load.
    SessionManager().startSession();
  }

  // Lock vault manually.
  void _lockVault() {
    SessionManager().lockNow();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'VaultMind',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Lock button in app bar.
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Lock Vault',
            onPressed: _lockVault,
          ),
        ],
      ),

      body: _buildBody(),

      // Bottom navigation.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Reset inactivity timer on navigation.
          SessionManager().resetTimer();
        },
        destinations: _sections
            .map(
              (s) => NavigationDestination(
                icon: Icon(s.icon),
                selectedIcon: Icon(s.activeIcon, color: s.color),
                label: s.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildFilesSection();
      case 1:
        return _buildNotesSection();
      case 2:
        return _buildPasswordsSection();
      case 3:
        return _buildSearchSection();
      default:
        return _buildFilesSection();
    }
  }

  // Files section placeholder.
  Widget _buildFilesSection() {
    return _buildComingSoon(
      icon: Icons.folder_outlined,
      title: 'Secure Files',
      subtitle: 'Store encrypted photos, videos, PDFs and documents',
      color: const Color(0xFF6C63FF),
    );
  }

  // Notes section placeholder.
  Widget _buildNotesSection() {
    return _buildComingSoon(
      icon: Icons.note_outlined,
      title: 'Encrypted Notes',
      subtitle: 'Private markdown notes and journals',
      color: const Color(0xFF43B89C),
    );
  }

  // Passwords section placeholder.
  Widget _buildPasswordsSection() {
    return _buildComingSoon(
      icon: Icons.key_outlined,
      title: 'Password Vault',
      subtitle: 'Securely store and manage your passwords',
      color: const Color(0xFFFF6584),
    );
  }

  // Search section placeholder.
  Widget _buildSearchSection() {
    return _buildComingSoon(
      icon: Icons.search_outlined,
      title: 'Smart Search',
      subtitle: 'Search across all your vault content',
      color: const Color(0xFFFFAA00),
    );
  }

  // Reusable coming soon widget for placeholders.
  Widget _buildComingSoon({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.3),
                ),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                'Coming in next phase',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple data class for vault sections.
class _VaultSection {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color color;

  _VaultSection({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.color,
  });
}