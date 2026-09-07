// Tests for offline resilience: connectivity + durable event queue.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/services/speech_recognizer.dart';
import 'package:accesscopilot/core/domain/services/speech_synthesizer.dart';
import 'package:accesscopilot/features/assistance/domain/assistant_controller.dart';
import 'package:accesscopilot/features/offline/domain/offline_controller.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';
import 'package:accesscopilot/features/onboarding/data/local_storage.dart';

class _FakeSpeech implements SpeechRecognizer {
  final bool available;
  _FakeSpeech({this.available = true});

  @override
  bool get isAvailable => available;

  @override
  SpeechStatus get status => SpeechStatus.idle;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _FakeTts implements SpeechSynthesizer {
  bool available = true;

  @override
  bool get isAvailable => available;

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ConnectivityController', () {
    test('starts online and toggles on notes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(connectivityProvider), isA<Online>());
      container.read(connectivityProvider.notifier).noteFailure();
      expect(container.read(connectivityProvider), isA<Offline>());
      container.read(connectivityProvider.notifier).noteFailure();
      expect(container.read(connectivityProvider), isA<Offline>());
      container.read(connectivityProvider.notifier).noteSuccess();
      expect(container.read(connectivityProvider), isA<Online>());
    });
  });

  group('EventQueue', () {
    test('enqueue persists and is restored from storage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final queue = container.read(eventQueueProvider.notifier);

      await queue.enqueue(
        CachedEvent(
          id: 'e-1',
          kind: 'assistant',
          payload: {'text': 'help'},
          createdAt: 1,
        ),
      );
      expect(container.read(eventQueueProvider), hasLength(1));

      // A fresh container (fresh in-memory SharedPreferences) still sees it.
      final stored = await SharedPreferences.getInstance();
      final lines = stored.getStringList(StorageKeys.eventQueue) ?? [];
      expect(lines, hasLength(1));
      expect(
        (jsonDecode(lines.first) as Map)['payload'],
        containsPair('text', 'help'),
      );
    });

    test('flush replays successful events and keeps failures', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final queue = container.read(eventQueueProvider.notifier);

      await queue.enqueue(
        CachedEvent(id: 'ok', kind: 'assistant', payload: {'text': 'a'}),
      );
      await queue.enqueue(
        CachedEvent(id: 'retry', kind: 'assistant', payload: {'text': 'b'}),
      );

      final sent = <String>[];
      final remaining = await queue.flush((event) async {
        sent.add(event.id);
        return event.id == 'ok';
      });

      expect(sent, ['ok', 'retry']);
      expect(remaining, 1);
      expect(container.read(eventQueueProvider).single.id, 'retry');
    });

    test('clear drops the persisted queue', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final queue = container.read(eventQueueProvider.notifier);

      await queue.enqueue(
        CachedEvent(id: 'x', kind: 'assistant', payload: const {}),
      );
      await queue.clear();
      expect(container.read(eventQueueProvider), isEmpty);
    });
  });

  group('AssistantController offline behaviour', () {
    test('failed submissions are queued and flagged offline', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            api.ApiClient(
              httpClient: MockClient(
                (request) async => http.Response('gateway down', 503),
              ),
            ),
          ),
          speechRecognizerProvider.overrideWithValue(_FakeSpeech()),
          speechSynthesizerProvider.overrideWithValue(_FakeTts()),
        ],
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);
      await container.read(assistantControllerProvider.notifier).submit('hello');

      expect(container.read(eventQueueProvider), hasLength(1));
      expect(
        container.read(eventQueueProvider).single.payload,
        containsPair('text', 'hello'),
      );
      expect(container.read(connectivityProvider), isA<Offline>());
      expect(container.read(assistantControllerProvider), isA<ConversationUnavailable>());
    });

    test('successful submission flushes queued assistant events', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            api.ApiClient(
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/assistant/query')) {
                  return http.Response(
                    jsonEncode({
                      'reply': 'Straight ahead for 20 metres.',
                      'detections': [],
                      'route_change': false,
                    }),
                    200,
                  );
                }
                return http.Response('{}', 200);
              }),
            ),
          ),
          speechRecognizerProvider.overrideWithValue(_FakeSpeech()),
          speechSynthesizerProvider.overrideWithValue(_FakeTts()),
        ],
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero);
      // Queue something that failed earlier, then a new live command.
      final queue = container.read(eventQueueProvider.notifier);
      await queue.enqueue(
        CachedEvent(id: 'old', kind: 'assistant', payload: {'text': 'queued'}),
      );

      await container
          .read(assistantControllerProvider.notifier)
          .submit('now online');

      expect(container.read(connectivityProvider), isA<Online>());
      expect(container.read(eventQueueProvider), isEmpty);
      final messages = container.read(assistantControllerProvider).messages;
      final copilotReplies =
          messages.where((m) => m.role == 'copilot').map((m) => m.text);
      expect(copilotReplies, hasLength(2)); // flush + live reply
    });
  });
}