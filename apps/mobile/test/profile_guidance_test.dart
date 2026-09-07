import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/core/domain/services/profile_guidance.dart';

void main() {
  test('default profile yields default, non-restrictive guidance', () {
    final guidance = ProfileGuidance(profile: const AccessibilityProfile());
    expect(guidance.preferAudioFirst, isFalse); // neutral by default
    expect(guidance.preferStepFreePaths, isFalse);
    expect(guidance.hapticIntensity, 1);
    expect(guidance.usePlainLanguage, isTrue); // low cognitive load default
    expect(guidance.detailLevel, 2);
  });

  test('wheelchair profile forces step-free routing and stronger haptics', () {
    final guidance = ProfileGuidance(
      profile: const AccessibilityProfile(mobility: MobilityAssistance.wheelchair),
    );
    expect(guidance.preferStepFreePaths, isTrue);
    expect(guidance.hapticIntensity, 2);
  });

  test('blind user gets spatial audio and simpler plain language', () {
    final guidance = ProfileGuidance(
      profile: const AccessibilityProfile(
        vision: VisionAssistance.blind,
        guidanceStyle: GuidanceStyle.concise,
      ),
    );
    expect(guidance.preferAudioFirst, isTrue);
    expect(guidance.usePlainLanguage, isTrue);
    expect(guidance.detailLevel, 1);
  });

  test('deaf user gets visual alternatives over audio', () {
    final guidance = ProfileGuidance(
      profile: const AccessibilityProfile(hearing: HearingAssistance.deaf),
    );
    expect(guidance.preferVisualAlternatives, isTrue);
  });

  test('detailed guidance style raises detail level', () {
    final guidance = ProfileGuidance(
      profile: const AccessibilityProfile(guidanceStyle: GuidanceStyle.detailed),
    );
    expect(guidance.detailLevel, 3);
  });

  test('slower users get a longer instruction pause', () {
    final slow = ProfileGuidance(
      profile: const AccessibilityProfile(walkingSpeedMps: 1.0),
    );
    final fast = ProfileGuidance(
      profile: const AccessibilityProfile(walkingSpeedMps: 1.6),
    );
    expect(slow.instructionPauseSeconds, greaterThan(fast.instructionPauseSeconds));
  });
}