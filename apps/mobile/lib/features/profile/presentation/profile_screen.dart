import 'package:flutter/material.dart';

/// Placeholder for the personalized profile screen.
///
/// The full profile experience (accessibility preferences, voice
/// settings, navigation preferences, privacy) is implemented in a later
/// milestone. This stub gives navigation a concrete destination.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile coming soon')),
    );
  }
}
