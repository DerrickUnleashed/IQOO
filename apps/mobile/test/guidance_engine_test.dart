// Tests for the unified guidance engine (audio + haptic delivery).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/core/domain/services/haptics.dart';
import 'package:accesscopilot/core/domain/services/speech_synthesizer.dart';
import 'package:accesscopilot/features/guidance/domain/guidance_engine.dart';

class _RecordingTts extends SpeechSynthesizer {
  final List<String> spoken = [];

  @override
  bool get isAvailable => true;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class _RecordingHaptics extends Haptics {
  final List<String> pulses = [];

  @override
  Future<void> light() async => pulses.add('light');

  @override
  Future<void> heavy() async => pulses.add('heavy');

  @override
  Future<void> doubleTap() async => pulses.add('double');

  @override
  Future<void> alert() async => pulses.add('alert');
}

final _step = api.RouteStep(
  instruction: 'Turn left at the corridor',
  actionType: 'turn',
  distanceM: 30,
);

void main() {
  test('hapticForAction maps routing actions to patterns', () {
    expect(hapticForAction('stairs'), 'alert');
    expect(hapticForAction('elevator'), 'double');
    expect(hapticForAction('ramp'), 'double');
    expect(hapticForAction('turn'), 'light');
    expect(hapticForAction('walk'), 'light');
  });

  test('simple-cognitive profile gets concise speech', () {
    final concise = AccessibilityProfile(cognitiveLoadPreference: 1);
    expect(
      speakForStep(_step, concise),
      'Turn left at the corridor. 30 m ahead.',
    );
  });

  test('detailed profile adds explanation', () {
    final detailed = AccessibilityProfile(
      guidanceStyle: GuidanceStyle.detailed,
    );
    final phrase = speakForStep(_step, detailed);
    expect(phrase, contains('Turn left at the corridor'));
    expect(phrase, contains('30 m ahead.'));
  });

  test('wheelchair warns on stairs during navigation', () async {
    final tts = _RecordingTts();
    final haptics = _RecordingHaptics();
    final container = ProviderContainer(
      overrides: [
        speechSynthesizerProvider.overrideWithValue(tts),
        hapticsProvider.overrideWithValue(haptics),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(guidanceEngineProvider);
    final profile = AccessibilityProfile(
      mobility: MobilityAssistance.wheelchair,
    );

    await engine.cueStep(
      api.RouteStep(
        instruction: 'Take the stairs',
        actionType: 'stairs',
        distanceM: 4,
      ),
      profile,
    );

    expect(tts.spoken.join(), contains('Stairs'));
    expect(tts.spoken.join(), contains('elevator'));
    expect(haptics.pulses, contains('alert'));
  });

  test('urgent scene objects are announced once and deduped', () async {
    final tts = _RecordingTts();
    final haptics = _RecordingHaptics();
    final container = ProviderContainer(
      overrides: [
        speechSynthesizerProvider.overrideWithValue(tts),
        hapticsProvider.overrideWithValue(haptics),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(guidanceEngineProvider);

    final blockage = api.SceneObject(
      id: 'o-1',
      type: 'obstacle',
      temporaryBlockage: true,
    );
    final stairs = api.SceneObject(
      id: 'o-2',
      type: 'stairs',
      accessible: false,
    );

    await engine.announceUrgentScene([blockage, stairs]);
    expect(tts.spoken, contains('Temporary blockage detected.'));
    expect(tts.spoken, contains('Stairs up ahead.'));
    expect(haptics.pulses.where((p) => p == 'alert'), hasLength(2));

    await engine.announceUrgentScene([blockage]);
    expect(tts.spoken, hasLength(2)); // unchanged
  });

  test('non-urgent furniture is not announced', () async {
    final tts = _RecordingTts();
    final haptics = _RecordingHaptics();
    final container = ProviderContainer(
      overrides: [
        speechSynthesizerProvider.overrideWithValue(tts),
        hapticsProvider.overrideWithValue(haptics),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(guidanceEngineProvider);

    await engine.announceUrgentScene([
      api.SceneObject(id: 'couch', type: 'furniture'),
    ]);

    expect(tts.spoken, isEmpty);
  });
}