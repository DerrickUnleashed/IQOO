// Tests for profile-aware routing cues.

import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/features/routing/domain/route_cues.dart';

api.RouteStep step({
  String instruction = 'Walk ahead',
  String actionType = 'walk',
  double? distance,
  String? required,
}) =>
    api.RouteStep(
      instruction: instruction,
      actionType: actionType,
      distanceM: distance,
      requiredAccessibility: required,
    );

void main() {
  final wheelchair = AccessibilityProfile(
    mobility: MobilityAssistance.wheelchair,
    guidanceStyle: GuidanceStyle.detailed,
  );
  final none = AccessibilityProfile();

  test('stairs are flagged urgent for wheelchair users', () {
    final cue = cueForStep(
      step(actionType: 'stairs', instruction: 'Take the stairs', distance: 4),
      wheelchair,
    );
    expect(cue.title, contains('elevator'));
    expect(cue.urgent, isTrue);
  });

  test('stairs are normal for ambulatory users', () {
    final cue = cueForStep(
      step(actionType: 'stairs', instruction: 'Take the stairs', distance: 4),
      none,
    );
    expect(cue.title, 'Take the stairs');
    expect(cue.urgent, isFalse);
    expect(cue.detail, '4 m to the stairs.');
  });

  test('elevator gets a wheelchair confirmation cue', () {
    final cue = cueForStep(
      step(actionType: 'elevator', required: 'elevator'),
      wheelchair,
    );
    expect(cue.detail, 'Elevator access confirmed.');
  });

  test('detailed guidance style adds distance to a plain walk', () {
    final cue = cueForStep(step(distance: 120), wheelchair);
    expect(cue.detail, '120 m ahead.');
  });

  test('distance and duration are formatted human-readably', () {
    expect(formatDistance(950), '950 m');
    expect(formatDistance(1000), '1.0 km');
    expect(formatDuration(90), '2m');
    expect(formatDuration(4000), '1h 7m');
    expect(formatDuration(null), '');
  });
}