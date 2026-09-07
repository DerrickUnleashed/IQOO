// Guidance engine: turns events into audio, haptic and visual cues.
//
// One entry point decides *what* the user gets told, and *how*, based on
// the accessibility profile. TTS speaks the cue, haptics pulse alongside
// it, and callers overlay visual emphasis. The profile governs the
// wording and whether longer explanations are allowed.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.g.dart' as api;
import '../../../core/domain/models/accessibility_profile.dart';
import '../../../core/domain/services/haptics.dart';
import '../../../core/domain/services/speech_synthesizer.dart';
import '../../routing/domain/route_cues.dart';

/// The haptic pattern attached to a routing action type.
String hapticForAction(String? actionType) => switch (actionType) {
      'elevator' || 'ramp' => 'double',
      'stairs' => 'alert',
      'turn' || 'left' || 'right' => 'light',
      _ => 'light',
    };

/// The textual warning level of a cue, used to pick presentation.
enum CueLevel { info, navigation, warning }

/// Builds the phrase that is spoken aloud for a routing step.
String speakForStep(api.RouteStep step, AccessibilityProfile profile) {
  final cue = cueForStep(step, profile);
  final detail = cue.detail.isNotEmpty ? ' ${cue.detail}' : '';
  final distance = step.distanceM != null && step.distanceM! > 0
      ? ' ${formatDistance(step.distanceM)} ahead.'
      : '';

  // "Ready ahead" style commands for the hard-of-hearing (visual
  // emphasis doubles up) and concise phrasing for low-cognitive-load.
  if (profile.prefersSimpleInstructions) {
    return '${cue.title}.$distance';
  }
  return '${cue.title}.$distance$detail';
}

/// Coordinates spoken + haptic delivery of a guidance event.
class GuidanceEngine {
  GuidanceEngine(this.ref);

  final Ref ref;

  /// Scene object ids already announced, so live updates don't spam.
  final Set<String> _announcedObjects = {};

  /// Speaks a routing step cue and pulses the matching haptic.
  Future<void> cueStep(api.RouteStep step, AccessibilityProfile profile) async {
    final level = cueForStep(step, profile).urgent
        ? CueLevel.warning
        : CueLevel.navigation;
    await announce(
      speakForStep(step, profile),
      level: level,
      actionKind: hapticForAction(step.actionType),
    );
  }

  /// Announces urgent objects from the live scene exactly once each,
  /// e.g. "stairs ahead" or "temporary blockage detected".
  Future<void> announceUrgentScene(List<api.SceneObject> objects) async {
    for (final object in objects) {
      if (_announcedObjects.contains(object.id)) continue;
      final urgent = object.temporaryBlockage == true ||
          (object.accessible == false && object.type != 'furniture');
      if (!urgent) continue;

      _announcedObjects.add(object.id);
      final message = switch (object.type) {
        'stairs' => 'Stairs up ahead.',
        'ramp' => 'Ramp detected.',
        'elevator' => 'Elevator here.',
        'obstacle' => 'Temporary blockage detected.',
        'restroom' => 'Accessible restroom nearby.',
        _ => object.type,
      };
      await announce(
        message,
        level: object.temporaryBlockage == true
            ? CueLevel.warning
            : CueLevel.navigation,
        actionKind: hapticForAction(object.type),
      );
    }
  }

  /// Delivers a plain announcement (scene alerts, arrival, errors).
  Future<void> announce(
    String text, {
    CueLevel level = CueLevel.info,
    String actionKind = 'light',
  }) async {
    if (text.trim().isEmpty) return;
    final tts = ref.read(speechSynthesizerProvider);
    if (tts.isAvailable) await tts.speak(text);

    final haptics = ref.read(hapticsProvider);
    try {
      switch (level) {
        case CueLevel.warning:
          await haptics.alert();
        case CueLevel.navigation:
          await haptics.forAction(actionKind);
        case CueLevel.info:
          await haptics.light();
      }
    } catch (_) {
      // Non-haptic platforms ignore pulses.
    }
  }
}

final guidanceEngineProvider = Provider<GuidanceEngine>(
  (ref) => GuidanceEngine(ref),
);