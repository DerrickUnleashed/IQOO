import '../../../../../core/domain/models/accessibility_profile.dart';

/// How guidance content is adapted for a given profile.
class ProfileGuidance {
  const ProfileGuidance({required this.profile});

  final AccessibilityProfile profile;

  /// Prefer audio-first instruction delivery.
  bool get preferAudioFirst =>
      profile.needsSpatialAudio || profile.guidanceStyle == GuidanceStyle.concise;

  /// Prefer visual alternatives (captions, text) for instructions.
  bool get preferVisualAlternatives => profile.needsVisualAlternatives;

  /// Routing should favor step-free, graded paths.
  bool get preferStepFreePaths => profile.usesWheelchair;

  /// Vibrate for every instruction type (strong for warnings).
  int get hapticIntensity => profile.usesWheelchair ? 2 : 1;

  /// How much supporting detail to include in a spoken instruction.
  int get detailLevel {
    return switch (profile.guidanceStyle) {
      GuidanceStyle.concise => 1,
      GuidanceStyle.normal => 2,
      GuidanceStyle.detailed => 3,
    };
  }

  /// Instructions are phrased without jargon when simple or low vision.
  bool get usePlainLanguage =>
      profile.prefersSimpleInstructions || profile.vision != VisionAssistance.none;

  /// A pause length (seconds) giving the user time to act.
  double get instructionPauseSeconds {
    var base = profile.walkingSpeedMps >= 1.5 ? 2.0 : 3.5;
    if (profile.mobility != MobilityAssistance.none) base += 1.0;
    return base;
  }
}