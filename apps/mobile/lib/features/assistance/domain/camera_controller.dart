import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lifecycle state of the camera subsystem.
sealed class CameraState {
  const CameraState();
}

class CameraInitializing extends CameraState {
  const CameraInitializing();
}

/// Camera requires permission from the user.
class CameraPermissionRequired extends CameraState {
  const CameraPermissionRequired();
}

/// Camera is ready and streaming frames.
class CameraReady extends CameraState {
  const CameraReady({required this.controller, required this.isTorchOn});
  final CameraController controller;
  final bool isTorchOn;
}

/// Camera is unavailable; provides a recovery action label.
class CameraUnavailable extends CameraState {
  const CameraUnavailable(this.message);
  final String message;
}

/// Camera discovery seam so the state machine can be tested without a
/// device (and a mock provider used in demo mode).
final cameraDiscoveryProvider = Provider<CameraDiscovery>((ref) {
  return const CameraDiscovery();
});

class CameraDiscovery {
  const CameraDiscovery();

  Future<List<CameraDescription>> discover() => availableCameras();
}

/// Manages the camera lifecycle: discovery, permissions, stream, torch,
/// and front/back switching. Degrades gracefully when no camera exists
/// (e.g. simulator/desktop) instead of crashing.
final cameraStateProvider = NotifierProvider<CameraNotifier, CameraState>(
  CameraNotifier.new,
);

class CameraNotifier extends Notifier<CameraState> {
  CameraController? _controller;
  bool _torchOn = false;
  int _cameraIndex = 0;

  @override
  CameraState build() {
    // Ensure the native camera is released when this provider is disposed.
    ref.onDispose(_disposeController);
    Future.microtask(initialize);
    return const CameraInitializing();
  }

  Future<void> initialize() async {
    final discovery = ref.read(cameraDiscoveryProvider);
    final List<CameraDescription> cameras;
    try {
      cameras = await discovery.discover();
    } on CameraException catch (e) {
      if (!ref.mounted) return;
      state = _fromException(e);
      return;
    } catch (_) {
      if (!ref.mounted) return;
      state = const CameraUnavailable(
        'The camera is not available on this device.',
      );
      return;
    }

    if (cameras.isEmpty) {
      if (!ref.mounted) return;
      state = const CameraUnavailable('No camera was found on this device.');
      return;
    }

    await _createController(cameras[_cameraIndex.clamp(0, cameras.length - 1)]);
  }

  Future<void> _createController(CameraDescription description) async {
    await _disposeController();
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      state = _fromException(e);
      return;
    }

    _controller = controller;
    state = CameraReady(controller: controller, isTorchOn: _torchOn);
  }

  Future<void> switchCamera() async {
    final discovery = ref.read(cameraDiscoveryProvider);
    final cameras = await discovery.discover();
    if (cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % 2;
    await _createController(cameras[_cameraIndex]);
  }

  Future<void> toggleTorch() async {
    final current = state;
    if (current is! CameraReady) return;
    try {
      _torchOn = !_torchOn;
      await current.controller.setFlashMode(
        _torchOn ? FlashMode.torch : FlashMode.off,
      );
      // Refresh state with the new torch value.
      state = CameraReady(controller: current.controller, isTorchOn: _torchOn);
    } on CameraException {
      _torchOn = !_torchOn;
    }
  }

  Future<void> _disposeController() {
    final c = _controller;
    _controller = null;
    if (c == null) return Future.value();
    return c.dispose();
  }
}

CameraState _fromException(CameraException e) {
  final code = e.code.toLowerCase();
  if (code.contains('permission') || code.contains('access')) {
    return const CameraPermissionRequired();
  }
  return CameraUnavailable(
    'The camera could not be started: ${e.description?.isEmpty ?? true ? e.code : e.description}',
  );
}
