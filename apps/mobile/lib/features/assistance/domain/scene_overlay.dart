import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/domain/services/profile_guidance.dart';
import '../../onboarding/domain/onboarding_providers.dart';
import 'scene_pipeline.dart';

/// Presents the live scene as profile-aware annotations for the overlay.
/// Emits an empty list whenever the pipeline has no live scene.
final sceneAnnotationsProvider = Provider<List<SceneAnnotation>>((ref) {
  final scene = ref.watch(scenePipelineStateProvider);
  if (scene is! SceneLive) return const [];
  final guidance = ref.watch(profileGuidanceProvider);
  return presentScene(objects: scene.sceneObjects, guidance: guidance);
});

/// An annotation rendered over the camera feed for one scene object.
class SceneAnnotation {
  const SceneAnnotation({
    required this.object,
    required this.label,
    required this.color,
    required this.urgent,
  });

  final api.SceneObject object;

  /// The human-oriented text describing the object.
  final String label;

  /// Accent color signaling accessibility state.
  final Color color;

  /// Whether the object needs immediate attention (e.g. a blockage).
  final bool urgent;
}

/// Builds the overlay annotations for a scene, personalized by guidance
/// detail level. Pure and unit-testable.
List<SceneAnnotation> presentScene({
  required List<api.SceneObject> objects,
  required ProfileGuidance guidance,
}) {
  final detail = guidance.detailLevel;
  return objects
      .where((o) => o.currentlyVisible != false)
      .map((o) => SceneAnnotation(
        object: o,
        label: _describe(o, detail: detail),
        color: _accentColor(o),
        urgent: o.temporaryBlockage == true || o.accessible == false,
      ))
      .toList();
}

String _describe(api.SceneObject o, {required int detail}) {
  final type = _humanize(o.type);
  final distance = o.distanceM;
  final direction = o.direction;

  if (detail <= 1) {
    return type;
  }

  final parts = <String>[type];
  if (distance != null) {
    parts.add('${distance.toStringAsFixed(0)} m');
  }
  if (direction != null && direction != api.Direction.unknown) {
    parts.add(direction.name);
  }
  if (detail >= 3) {
    final state = o.state;
    if (state != null && state.isNotEmpty) {
      parts.add(state);
    }
    if (o.temporaryBlockage == true) {
      parts.add('blocked');
    }
  }
  return parts.join(' · ');
}

Color _accentColor(api.SceneObject o) {
  if (o.temporaryBlockage == true || o.accessible == false) {
    return const Color(0xFFD32F2F); // urgent red
  }
  if (o.accessible == true) {
    return const Color(0xFF2E7D32); // accessible green
  }
  return Colors.white70; // unknown / neutral
}

String _humanize(String type) {
  if (type.isEmpty) return 'object';
  return type.replaceAll('_', ' ');
}