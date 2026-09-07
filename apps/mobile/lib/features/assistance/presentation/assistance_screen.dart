import 'package:flutter/material.dart';

/// Placeholder for the live assistance experience.
///
/// The full camera + perception + voice experience is implemented in a
/// later milestone. This stub gives navigation a concrete destination.
class AssistanceScreen extends StatelessWidget {
  const AssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistance')),
      body: const Center(child: Text('Live assistance coming soon')),
    );
  }
}
