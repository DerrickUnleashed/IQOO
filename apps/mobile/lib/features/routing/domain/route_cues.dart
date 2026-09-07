// Profile-aware guidance cues for a routing step.

import 'dart:math' as math;

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/domain/models/accessibility_profile.dart';

/// What the user sees (and later hears/feels — COMMIT 20) for a step.
class RouteCue {
  const RouteCue({
    required this.title,
    required this.detail,
    required this.icon,
    this.urgent = false,
  });

  final String title;
  final String detail;
  final String icon;
  final bool urgent;
}

/// Renders a step as a cue adapted to the user's accessibility profile.
RouteCue cueForStep(api.RouteStep step, AccessibilityProfile profile) {
  final action = (step.actionType ?? 'walk').toLowerCase();
  final required = step.requiredAccessibility?.toLowerCase() ?? '';

  String title = step.instruction;
  String detail = '';
  String icon = 'walk';

  switch (action) {
    case 'elevator':
      title = step.instruction.isNotEmpty
          ? step.instruction
          : 'Take the elevator';
      icon = 'elevator';
      if (profile.usesWheelchair && !required.contains('elevator')) {
        detail = 'Look for the wheelchair-accessible elevator.';
      } else if (required.contains('elevator')) {
        detail = 'Elevator access confirmed.';
      }
    case 'stairs':
      icon = 'stairs';
      if (profile.usesWheelchair) {
        title = 'Stairs ahead — use the elevator instead';
        detail = 'This route has stairs, which are not wheelchair accessible.';
        return RouteCue(
          title: title,
          detail: detail,
          icon: icon,
          urgent: true,
        );
      }
      detail = '${step.distanceM?.round() ?? 0} m to the stairs.';
    case 'ramp':
      icon = 'ramp';
      detail = 'Ramp available here.';
    case 'turn':
      icon = 'turn';
    default:
      if (required.contains('accessible_restroom')) {
        detail = 'Accessible restroom nearby.';
      }
  }

  if (profile.guidanceStyle == GuidanceStyle.detailed && detail.isEmpty) {
    detail = '${step.distanceM?.round() ?? 0} m ahead.';
  }

  return RouteCue(title: title, detail: detail, icon: icon);
}

String formatDistance(double? metres) {
  final value = metres ?? 0;
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)} km';
  }
  return '${value.round()} m';
}

String formatDuration(int? seconds) {
  if (seconds == null) return '';
  final minutes = math.max(1, (seconds / 60).round());
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    return '${h}h ${minutes % 60}m';
  }
  return '${minutes}m';
}