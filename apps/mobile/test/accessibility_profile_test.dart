// Tests for the accessibility profile model and serialization.

import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';

void main() {
  group('AccessibilityProfile', () {
    test('defaults to no assistance and normal guidance', () {
      const profile = AccessibilityProfile();

      expect(profile.mobility, MobilityAssistance.none);
      expect(profile.vision, VisionAssistance.none);
      expect(profile.hearing, HearingAssistance.none);
      expect(profile.guidanceStyle, GuidanceStyle.normal);
      expect(profile.cognitiveLoadPreference, 1);
    });

    test('round-trips through JSON', () {
      const profile = AccessibilityProfile(
        mobility: MobilityAssistance.wheelchair,
        vision: VisionAssistance.lowVision,
        hearing: HearingAssistance.hearingAid,
        guidanceStyle: GuidanceStyle.concise,
        walkingSpeedMps: 0.9,
        maxComfortableDistanceM: 100,
        cognitiveLoadPreference: 1,
      );

      final restored =
          AccessibilityProfile.fromJson(profile.toJson());

      expect(restored.mobility, MobilityAssistance.wheelchair);
      expect(restored.vision, VisionAssistance.lowVision);
      expect(restored.hearing, HearingAssistance.hearingAid);
      expect(restored.guidanceStyle, GuidanceStyle.concise);
      expect(restored.walkingSpeedMps, 0.9);
      expect(restored.maxComfortableDistanceM, 100);
      expect(restored.cognitiveLoadPreference, 1);
    });

    test('copyWith updates only the given fields', () {
      const profile = AccessibilityProfile();
      final updated = profile.copyWith(mobility: MobilityAssistance.cane);

      expect(updated.mobility, MobilityAssistance.cane);
      expect(updated.vision, VisionAssistance.none);
      expect(updated.guidanceStyle, GuidanceStyle.normal);
    });

    test('helper flags reflect the profile', () {
      const wheelchair = AccessibilityProfile(
        mobility: MobilityAssistance.wheelchair,
      );
      expect(wheelchair.usesWheelchair, isTrue);
      expect(wheelchair.needsSpatialAudio, isFalse);

      const lowVision = AccessibilityProfile(vision: VisionAssistance.lowVision);
      expect(lowVision.needsSpatialAudio, isTrue);

      const deaf = AccessibilityProfile(hearing: HearingAssistance.deaf);
      expect(deaf.needsVisualAlternatives, isTrue);
    });

    test('storage keys round-trip', () {
      for (final v in MobilityAssistance.values) {
        expect(
          MobilityAssistance.fromStorageKey(v.storageKey),
          v,
        );
      }
      for (final v in GuidanceStyle.values) {
        expect(GuidanceStyle.fromStorageKey(v.storageKey), v);
      }
    });
  });
}