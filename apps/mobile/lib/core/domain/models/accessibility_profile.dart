/// How a user needs help with mobility.
enum MobilityAssistance {
  none,
  temporaryMobility,
  wheelchair,
  walkingAid,
  cane;

  String get label => switch (this) {
    MobilityAssistance.none => 'No assistance',
    MobilityAssistance.temporaryMobility => 'Temporary mobility support',
    MobilityAssistance.wheelchair => 'Wheelchair',
    MobilityAssistance.walkingAid => 'Walking aid',
    MobilityAssistance.cane => 'Cane',
  };

  /// Storage key used for persistence.
  String get storageKey => switch (this) {
    MobilityAssistance.none => 'none',
    MobilityAssistance.temporaryMobility => 'temporary_mobility',
    MobilityAssistance.wheelchair => 'wheelchair',
    MobilityAssistance.walkingAid => 'walking_aid',
    MobilityAssistance.cane => 'cane',
  };

  static MobilityAssistance fromStorageKey(String key) =>
      MobilityAssistance.values.firstWhere(
        (v) => v.storageKey == key,
        orElse: () => MobilityAssistance.none,
      );
}

/// How a user needs help with vision.
enum VisionAssistance {
  none,
  temporaryVision,
  lowVision,
  blind;

  String get label => switch (this) {
    VisionAssistance.none => 'No assistance',
    VisionAssistance.temporaryVision => 'Temporary visual support',
    VisionAssistance.lowVision => 'Low vision',
    VisionAssistance.blind => 'Blind',
  };

  String get storageKey => switch (this) {
    VisionAssistance.none => 'none',
    VisionAssistance.temporaryVision => 'temporary_vision',
    VisionAssistance.lowVision => 'low_vision',
    VisionAssistance.blind => 'blind',
  };

  static VisionAssistance fromStorageKey(String key) =>
      VisionAssistance.values.firstWhere(
        (v) => v.storageKey == key,
        orElse: () => VisionAssistance.none,
      );
}

/// How a user needs help with hearing.
enum HearingAssistance {
  none,
  hearingAid,
  deaf;

  String get label => switch (this) {
    HearingAssistance.none => 'No assistance',
    HearingAssistance.hearingAid => 'Hearing aid',
    HearingAssistance.deaf => 'Deaf / hard of hearing',
  };

  String get storageKey => switch (this) {
    HearingAssistance.none => 'none',
    HearingAssistance.hearingAid => 'hearing_aid',
    HearingAssistance.deaf => 'deaf',
  };

  static HearingAssistance fromStorageKey(String key) =>
      HearingAssistance.values.firstWhere(
        (v) => v.storageKey == key,
        orElse: () => HearingAssistance.none,
      );
}

/// How a user prefers guidance to be delivered.
enum GuidanceStyle {
  concise,
  normal,
  detailed;

  String get label => switch (this) {
    GuidanceStyle.concise => 'Concise',
    GuidanceStyle.normal => 'Normal',
    GuidanceStyle.detailed => 'Detailed',
  };

  String get storageKey => switch (this) {
    GuidanceStyle.concise => 'concise',
    GuidanceStyle.normal => 'normal',
    GuidanceStyle.detailed => 'detailed',
  };

  static GuidanceStyle fromStorageKey(String key) =>
      GuidanceStyle.values.firstWhere(
        (v) => v.storageKey == key,
        orElse: () => GuidanceStyle.normal,
      );
}

/// The complete accessibility profile that personalizes all guidance.
///
/// This is user-dependent by design: the same environment produces
/// different recommendations for different profiles. No user is assumed
/// to have a permanent disability; a fully "none" profile is valid.
class AccessibilityProfile {
  const AccessibilityProfile({
    this.mobility = MobilityAssistance.none,
    this.vision = VisionAssistance.none,
    this.hearing = HearingAssistance.none,
    this.guidanceStyle = GuidanceStyle.normal,
    this.walkingSpeedMps = 1.2,
    this.maxComfortableDistanceM = 100,
    this.cognitiveLoadPreference = 1,
  });

  final MobilityAssistance mobility;
  final VisionAssistance vision;
  final HearingAssistance hearing;
  final GuidanceStyle guidanceStyle;

  /// Estimated walking speed in meters per second.
  final double walkingSpeedMps;

  /// Maximum distance the user is comfortable covering in one stretch.
  final int maxComfortableDistanceM;

  /// 1 = keep instructions minimal, 3 = allow longer explanations.
  final int cognitiveLoadPreference;

  bool get usesWheelchair => mobility == MobilityAssistance.wheelchair;

  bool get prefersSimpleInstructions => cognitiveLoadPreference <= 1;

  bool get needsSpatialAudio => vision != VisionAssistance.none;

  bool get needsVisualAlternatives => hearing != HearingAssistance.none;

  AccessibilityProfile copyWith({
    MobilityAssistance? mobility,
    VisionAssistance? vision,
    HearingAssistance? hearing,
    GuidanceStyle? guidanceStyle,
    double? walkingSpeedMps,
    int? maxComfortableDistanceM,
    int? cognitiveLoadPreference,
  }) {
    return AccessibilityProfile(
      mobility: mobility ?? this.mobility,
      vision: vision ?? this.vision,
      hearing: hearing ?? this.hearing,
      guidanceStyle: guidanceStyle ?? this.guidanceStyle,
      walkingSpeedMps: walkingSpeedMps ?? this.walkingSpeedMps,
      maxComfortableDistanceM:
          maxComfortableDistanceM ?? this.maxComfortableDistanceM,
      cognitiveLoadPreference:
          cognitiveLoadPreference ?? this.cognitiveLoadPreference,
    );
  }

  /// Serializes to a JSON map for persistence.
  Map<String, dynamic> toJson() => {
    'mobility': mobility.storageKey,
    'vision': vision.storageKey,
    'hearing': hearing.storageKey,
    'guidance_style': guidanceStyle.storageKey,
    'walking_speed_mps': walkingSpeedMps,
    'max_comfortable_distance_m': maxComfortableDistanceM,
    'cognitive_load_preference': cognitiveLoadPreference,
  };

  factory AccessibilityProfile.fromJson(Map<String, dynamic> json) {
    return AccessibilityProfile(
      mobility: MobilityAssistance.fromStorageKey(
        json['mobility'] as String? ?? 'none',
      ),
      vision: VisionAssistance.fromStorageKey(
        json['vision'] as String? ?? 'none',
      ),
      hearing: HearingAssistance.fromStorageKey(
        json['hearing'] as String? ?? 'none',
      ),
      guidanceStyle: GuidanceStyle.fromStorageKey(
        json['guidance_style'] as String? ?? 'normal',
      ),
      walkingSpeedMps: (json['walking_speed_mps'] as num?)?.toDouble() ?? 1.2,
      maxComfortableDistanceM:
          (json['max_comfortable_distance_m'] as num?)?.toInt() ?? 100,
      cognitiveLoadPreference:
          (json['cognitive_load_preference'] as num?)?.toInt() ?? 1,
    );
  }
}
