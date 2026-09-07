import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../onboarding/domain/app_client_providers.dart';
import '../../onboarding/domain/session_controller.dart';
import 'frame_encoder.dart';
import 'frame_source.dart';

/// Live state of the perception pipeline.
sealed class ScenePipelineState {
  const ScenePipelineState();
}

/// The pipeline has not started or has been detached.
class SceneIdle extends ScenePipelineState {
  const SceneIdle();
}

/// A frame is currently being analyzed against the backend.
class SceneAnalyzing extends ScenePipelineState {
  const SceneAnalyzing();
}

/// The latest frame was analyzed successfully; the scene is live.
class SceneLive extends ScenePipelineState {
  const SceneLive({
    required this.sceneObjects,
    required this.summary,
    required this.updatedAt,
  });

  final List<api.SceneObject> sceneObjects;
  final Map<String, dynamic>? summary;
  final DateTime updatedAt;
}

/// The pipeline cannot reach perception (offline / error). The most recent
/// scene objects are retained so the overlay can keep rendering.
class SceneDegraded extends ScenePipelineState {
  const SceneDegraded({required this.message, required this.sceneObjects});

  final String message;
  final List<api.SceneObject> sceneObjects;
}

/// Runs the live camera scene pipeline: encoded frames are throttled to the
/// perception endpoint, detections are merged into the backend scene graph,
/// and the resulting scene is exposed for the overlay.
///
/// The pipeline degrades gracefully: when the backend is unreachable it
/// reports SceneDegraded while retaining the last known scene, and recovers
/// on the next frame. Frame submissions are gated so at most one analysis
/// is in flight at a time.
class ScenePipelineController extends Notifier<ScenePipelineState> {
  ScenePipelineController();

  static const _minFrameInterval = Duration(milliseconds: 1500);

  FrameSource? _source;
  DateTime? _lastAnalyzedAt;
  var _inFlight = false;
  var _frameCounter = 0;

  List<api.SceneObject> _retainedObjects = const [];
  Map<String, dynamic>? _retainedSummary;

  @override
  ScenePipelineState build() {
    ref.onDispose(() {
      final source = _source;
      _source = null;
      source?.stop();
    });
    return const SceneIdle();
  }

  /// Starts the pipeline from a live camera controller.
  Future<void> attachCamera(CameraController controller) async {
    final source = NativeCameraFrameSource(
      controller,
      encoder: ref.read(frameEncoderProvider),
    );
    await attach(source);
  }

  /// Starts the pipeline from an arbitrary frame source (test seam).
  Future<void> attach(FrameSource source) async {
    await detach();
    _source = source;
    state = const SceneIdle();
    try {
      await source.start(ingestFrame);
    } catch (_) {
      if (!ref.mounted) return;
      state = SceneDegraded(
        message: 'The camera feed could not be started.',
        sceneObjects: _retainedObjects,
      );
    }
  }

  /// Stops the frame stream and clears the live scene.
  Future<void> detach() async {
    final source = _source;
    _source = null;
    _retainedObjects = const [];
    _retainedSummary = null;
    _inFlight = false;
    state = const SceneIdle();
    await source?.stop();
  }

  /// Returns true and enqueues analysis when the frame should be processed,
  /// or false when throttled or while another analysis is in flight.
  bool ingestFrame(String encodedFrame) {
    final now = DateTime.now();
    final last = _lastAnalyzedAt;
    final throttled =
        last != null && now.difference(last) < _minFrameInterval;
    if (throttled || _inFlight) return false;

    _frameCounter++;
    final frameId = '${now.millisecondsSinceEpoch}-$_frameCounter';
    unawaited(_processFrame(frameId, encodedFrame));
    return true;
  }

  Future<void> _processFrame(String frameId, String encodedFrame) async {
    if (_inFlight) return;
    _inFlight = true;
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }

    state = const SceneAnalyzing();

    final session = ref.read(sessionControllerProvider);
    final client = ref.read(apiClientProvider);

    try {
      final detections = await client.analyzeFrame(
        body: api.AnalyzeFrameRequest(
          frameId: frameId,
          sessionId: session.sessionId ?? '',
          encodedFrame: encodedFrame,
        ),
      );
      final scene = await client.updateScene(
        body: api.SceneUpdate(
          sessionId: session.sessionId ?? '',
          detections: detections.detections,
          location: detections.sceneSummary,
        ),
      );

      if (!ref.mounted) return;
      _retainedObjects = scene.sceneObjects;
      _retainedSummary = detections.sceneSummary;
      state = SceneLive(
        sceneObjects: _retainedObjects,
        summary: _retainedSummary,
        updatedAt: DateTime.now(),
      );
      _lastAnalyzedAt = DateTime.now();
    } on Exception {
      if (!ref.mounted) return;
      state = SceneDegraded(
        message: 'Perception is unavailable right now.',
        sceneObjects: _retainedObjects,
      );
    } finally {
      _inFlight = false;
    }
  }
}

final scenePipelineStateProvider =
    NotifierProvider<ScenePipelineController, ScenePipelineState>(
      ScenePipelineController.new,
    );