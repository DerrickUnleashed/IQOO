import 'package:camera/camera.dart';

import 'frame_encoder.dart';

/// Emits encoded camera frames (base64 JPEG) for the perception pipeline.
///
/// Kept abstract so unit tests can drive the pipeline with synthetic frames
/// and so the pipeline itself never depends on the camera plugin.
abstract class FrameSource {
  /// Begins streaming frames, invoking [onFrame] with each encoded payload.
  Future<void> start(void Function(String encoded) onFrame);

  /// Stops streaming. Safe to call more than once.
  Future<void> stop();
}

/// A [FrameSource] backed by the device camera.
class NativeCameraFrameSource implements FrameSource {
  NativeCameraFrameSource(this.controller, {FrameEncoder? encoder})
      : _encoder = encoder ?? defaultEncodeFrame;

  final CameraController controller;
  final FrameEncoder _encoder;

  void Function(String)? _onFrame;
  var _started = false;

  @override
  Future<void> start(void Function(String encoded) onFrame) async {
    _onFrame = onFrame;
    _started = true;
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream((image) {
      final encoded = _encoder(image);
      if (encoded != null) _onFrame?.call(encoded);
    });
  }

  @override
  Future<void> stop() async {
    final wasStarted = _started;
    _started = false;
    _onFrame = null;
    if (wasStarted) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // The controller may already be torn down; nothing to do.
      }
    }
  }
}