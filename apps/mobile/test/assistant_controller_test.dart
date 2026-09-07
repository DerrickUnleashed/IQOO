// Tests for the copilot assistant conversation controller.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/services/haptics.dart';
import 'package:accesscopilot/core/domain/services/speech_recognizer.dart';
import 'package:accesscopilot/core/domain/services/speech_synthesizer.dart';
import 'package:accesscopilot/features/assistance/domain/assistant_controller.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';

class _FakeSpeech implements SpeechRecognizer {
  bool available = true;
  SpeechStatus _status = SpeechStatus.idle;
  bool started = false;
  void Function(String, bool)? onResult;
  void Function()? onDone;

  @override
  bool get isAvailable => available;

  @override
  SpeechStatus get status => _status;

  @override
  Future<void> initialize() async {
    if (available) _status = SpeechStatus.idle;
  }

  @override
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    started = true;
    _status = SpeechStatus.listening;
    this.onResult = onResult;
    this.onDone = onDone;
    return true;
  }

  @override
  Future<void> stop() async {
    _status = SpeechStatus.idle;
    onDone?.call();
  }
}

class _FakeTts implements SpeechSynthesizer {
  final List<String> spoken = [];
  bool available = true;

  @override
  bool get isAvailable => available;

  @override
  Future<void> speak(String text) async => spoken.add(text);

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

ProviderContainer _container({
  required _FakeSpeech speech,
  required _FakeTts tts,
  required _RecordingHaptics haptics,
  Future<http.Response> Function(http.Request)? handler,
}) {
  final client = api.ApiClient(
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/auth/session')) {
        return http.Response(
          jsonEncode({
            'session_id': 'sess-1',
            'user_id': 1,
            'started_at': '2026-01-01T00:00:00Z',
            'status': 'active',
          }),
          200,
        );
      }
      if (handler != null) return handler(request);
      return http.Response('{}', 200);
    }),
  );
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      speechRecognizerProvider.overrideWithValue(speech),
      speechSynthesizerProvider.overrideWithValue(tts),
      hapticsProvider.overrideWithValue(haptics),
    ],
  );
}

http.Response _assistantReply({String? haptics, String? actionKind}) {
  return http.Response(
    jsonEncode({
      'reply': 'There is a ramp ahead on your right.',
      'action': actionKind == null
          ? null
          : {
              'title': 'Turn right at the ramp',
              'kind': actionKind,
              'confidence': 0.8,
              'haptics': haptics,
            },
      'detections': [],
      'route_change': false,
    }),
    200,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AssistantController', () {
    test('submits text and records the copilot reply', () async {
      final tts = _FakeTts();
      final container = _container(
        speech: _FakeSpeech(),
        tts: tts,
        haptics: _RecordingHaptics(),
        handler: (request) async =>
            request.url.path.endsWith('/assistant/query')
                ? _assistantReply()
                : http.Response('{}', 200),
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final notifier = container.read(assistantControllerProvider.notifier);
      await notifier.submit('How do I reach the exit?');

      final state = container.read(assistantControllerProvider);
      expect(state, isA<ConversationReplied>());
      final replied = state as ConversationReplied;
      expect(replied.messages, hasLength(2));
      expect(replied.messages.first.role, 'user');
      expect(replied.messages.last.role, 'copilot');
      expect(replied.messages.last.text, contains('ramp'));
      expect(tts.spoken, hasLength(1));
    });

    test('plays haptics when the reply carries an action', () async {
      final haptics = _RecordingHaptics();
      final container = _container(
        speech: _FakeSpeech(),
        tts: _FakeTts(),
        haptics: haptics,
        handler: (request) async =>
            request.url.path.endsWith('/assistant/query')
                ? _assistantReply(haptics: 'double', actionKind: 'instruction')
                : http.Response('{}', 200),
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final notifier = container.read(assistantControllerProvider.notifier);
      await notifier.submit('Where is the ramp?');

      final replied = container.read(
        assistantControllerProvider,
      ) as ConversationReplied;
      expect(replied.messages.last.action, isNotNull);
      expect(haptics.pulses, ['double']);
    });

    test('startListening routes final speech through submit', () async {
      final speech = _FakeSpeech();
      final container = _container(
        speech: speech,
        tts: _FakeTts(),
        haptics: _RecordingHaptics(),
        handler: (request) async =>
            request.url.path.endsWith('/assistant/query')
                ? _assistantReply()
                : http.Response('{}', 200),
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final notifier = container.read(assistantControllerProvider.notifier);

      final started = await notifier.startListening();
      expect(started, isTrue);
      expect(
        container.read(assistantControllerProvider),
        isA<ConversationListening>(),
      );

      speech.onResult?.call('turn right at the ramp', true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(assistantControllerProvider);
      expect(state, isA<ConversationReplied>());
      expect((state as ConversationReplied).messages.first.text,
          'turn right at the ramp');
    });

    test('degrades when voice is unavailable', () async {
      final speech = _FakeSpeech()..available = false;
      final container = _container(
        speech: speech,
        tts: _FakeTts(),
        haptics: _RecordingHaptics(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(assistantControllerProvider.notifier);
      final started = await notifier.startListening();
      expect(started, isFalse);
      expect(
        container.read(assistantControllerProvider),
        isA<ConversationUnavailable>(),
      );
    });
  });
}