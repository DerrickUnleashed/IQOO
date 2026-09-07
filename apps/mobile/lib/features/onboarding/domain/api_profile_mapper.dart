import '../../../../core/domain/models/accessibility_profile.dart';
import '../../../../core/api/api_client.g.dart' as api;

/// Adapts between the app's typed profile model and the wire API DTO.
///
/// Keeps the UI model (typed enums, safe defaults) decoupled from the
/// raw string values the backend accepts.
class ApiProfileMapper {
  const ApiProfileMapper._();

  static api.ProfileUpdate toApiUpdate(AccessibilityProfile profile) {
    return api.ProfileUpdate(
      mobility: profile.mobility.storageKey,
      vision: profile.vision.storageKey,
      hearing: profile.hearing.storageKey,
      guidanceStyle: profile.guidanceStyle.storageKey,
      walkingSpeedMps: profile.walkingSpeedMps,
      maxComfortableDistanceM: profile.maxComfortableDistanceM,
      cognitiveLoadPreference: profile.cognitiveLoadPreference,
    );
  }

  /// Wire DTO for route requests (backend accepts the raw profile).
  static api.AccessibilityProfile toApi(AccessibilityProfile profile) {
    return api.AccessibilityProfile(
      mobility: profile.mobility.storageKey,
      vision: profile.vision.storageKey,
      hearing: profile.hearing.storageKey,
      guidanceStyle: profile.guidanceStyle.storageKey,
      walkingSpeedMps: profile.walkingSpeedMps,
      maxComfortableDistanceM: profile.maxComfortableDistanceM,
      cognitiveLoadPreference: profile.cognitiveLoadPreference,
    );
  }

  static AccessibilityProfile fromApi(api.AccessibilityProfile dto) {
    return AccessibilityProfile(
      mobility: MobilityAssistance.fromStorageKey(dto.mobility ?? 'none'),
      vision: VisionAssistance.fromStorageKey(dto.vision ?? 'none'),
      hearing: HearingAssistance.fromStorageKey(dto.hearing ?? 'none'),
      guidanceStyle: GuidanceStyle.fromStorageKey(
        dto.guidanceStyle ?? 'normal',
      ),
      walkingSpeedMps: dto.walkingSpeedMps ?? 1.2,
      maxComfortableDistanceM: dto.maxComfortableDistanceM ?? 100,
      cognitiveLoadPreference: dto.cognitiveLoadPreference ?? 1,
    );
  }
}