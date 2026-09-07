// Widget tests for the live assistance screen's graceful states.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/features/assistance/domain/camera_controller.dart';
import 'package:accesscopilot/features/assistance/presentation/assistance_screen.dart';

void main() {
  group('AssistanceScreen', () {
    testWidgets('shows camera unavailable message when no cameras exist', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          cameraDiscoveryProvider.overrideWithValue(_EmptyDiscovery()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AssistanceScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Camera unavailable'), findsOneWidget);
      expect(find.text('No camera was found on this device.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

class _EmptyDiscovery extends CameraDiscovery {
  @override
  Future<List<CameraDescription>> discover() async => const [];
}
