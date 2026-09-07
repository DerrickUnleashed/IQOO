import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/features/onboarding/domain/api_profile_mapper.dart';

void main() {
  group('ApiProfileMapper', () {
    test('maps a typed profile onto an API update with storage keys', () {
      final profile = AccessibilityProfile(
        mobility: MobilityAssistance.wheelchair,
        vision: VisionAssistance.lowVision,
        hearing: HearingAssistance.hearingAid,
        guidanceStyle: GuidanceStyle.detailed,
        walkingSpeedMps: 1.0,
        maxComfortableDistanceM: 60,
        cognitiveLoadPreference: 2,
      );

      final update = ApiProfileMapper.toApiUpdate(profile);

      expect(update.mobility, 'wheelchair');
      expect(update.vision, 'low_vision');
      expect(update.hearing, 'hearing_aid');
      expect(update.guidanceStyle, 'detailed');
      expect(update.walkingSpeedMps, 1.0);
      expect(update.maxComfortableDistanceM, 60);
      expect(update.cognitiveLoadPreference, 2);
    });

    test('maps an API profile back onto typed enums with safe defaults', () {
      final dto = api.AccessibilityProfile(
        mobility: 'cane',
        vision: 'blind',
        hearing: 'none',
        guidanceStyle: 'concise',
        walkingSpeedMps: 1.3,
        maxComfortableDistanceM: 200,
        cognitiveLoadPreference: 3,
      );

      final profile = ApiProfileMapper.fromApi(dto);

      expect(profile.mobility, MobilityAssistance.cane);
      expect(profile.vision, VisionAssistance.blind);
      expect(profile.hearing, HearingAssistance.none);
      expect(profile.guidanceStyle, GuidanceStyle.concise);
      expect(profile.walkingSpeedMps, 1.3);
      expect(profile.maxComfortableDistanceM, 200);
      expect(profile.cognitiveLoadPreference, 3);
    });

    test('unrecognized or null values fall back to safe defaults', () {
      final profile = ApiProfileMapper.fromApi(
        api.AccessibilityProfile(mobility: 'hoverboard', walkingSpeedMps: null),
      );
      expect(profile.mobility, MobilityAssistance.none);
      expect(profile.walkingSpeedMps, 1.2);
    });
  });
}