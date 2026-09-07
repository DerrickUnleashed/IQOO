// Tests for the camera state machine without a live device.

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/features/assistance/domain/camera_controller.dart';

void main() {
  group('CameraNotifier state machine', () {
    test('initializes to initializing state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(cameraStateProvider), isA<CameraInitializing>());
    });

    test('degrades to unavailable when no cameras are found', () async {
      final container = ProviderContainer(
        overrides: [
          cameraDiscoveryProvider.overrideWithValue(const _EmptyDiscovery()),
        ],
      );
      addTearDown(container.dispose);

      container.read(cameraStateProvider);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(container.read(cameraStateProvider), isA<CameraUnavailable>());
    });

    test(
      'requests permission when discovery reports a permission error',
      () async {
        final container = ProviderContainer(
          overrides: [
            cameraDiscoveryProvider.overrideWithValue(
              _ThrowingDiscovery(
                CameraException(
                  'CameraAccessDenied',
                  'Camera access was denied.',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(cameraStateProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(
          container.read(cameraStateProvider),
          isA<CameraPermissionRequired>(),
        );
      },
    );

    test('degrades to unavailable on unexpected discovery errors', () async {
      final container = ProviderContainer(
        overrides: [
          cameraDiscoveryProvider.overrideWithValue(
            _ThrowingDiscovery(StateError('boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(cameraStateProvider);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(container.read(cameraStateProvider), isA<CameraUnavailable>());
    });
  });
}

class _EmptyDiscovery extends CameraDiscovery {
  const _EmptyDiscovery();

  @override
  Future<List<CameraDescription>> discover() async => const [];
}

class _ThrowingDiscovery extends CameraDiscovery {
  const _ThrowingDiscovery(this.error);

  final Object error;

  @override
  Future<List<CameraDescription>> discover() async => throw error;
}
