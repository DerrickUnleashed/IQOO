import 'package:flutter/material.dart';

/// The assistant home screen.
///
/// This is a minimal shell that will be fully designed in a later milestone.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AccessCopilot')),
      body: const Center(child: Text('Home screen')),
    );
  }
}
