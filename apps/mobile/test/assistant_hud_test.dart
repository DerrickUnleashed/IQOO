// Widget tests for the copilot assistant HUD over the camera feed.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/services/speech_recognizer.dart';
import 'package:accesscopilot/features/assistance/domain/assistant_controller.dart';
import 'package:accesscopilot/features/assistance/presentation/assistant_hud.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';

class _FakeSpeech implements SpeechRecognizer {
  bool available = true;
  bool started = false;
  void Function(String, bool)? onResult;

  @override
  bool get isAvailable => available;

  @override
  SpeechStatus get status =>
      started ? SpeechStatus.listening : SpeechStatus.idle;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    started = true;
    this.onResult = onResult;
    return true;
  }

  @override
  Future<void> stop() async {
    started = false;
    onResult = null;
  }
}

Widget _wrap() {
  final client = api.ApiClient(
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/assistant/query')) {
        return http.Response(
          jsonEncode({
            'reply': 'The exit is straight ahead.',
            'detections': [],
            'route_change': false,
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    }),
  );
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: AssistantHud(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the copilot header and a hold-to-talk hint',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Copilot'), findsOneWidget);
    expect(find.text('Hold to talk'), findsOneWidget);
    expect(find.text('Ask anything…'), findsOneWidget);
  });

  testWidgets('submitting text records a user bubble', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'where is the exit');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Conversation mode shows the user message bubble.
    final container = ProviderScope.containerOf(tester.element(find.byType(TextField)));
    final state = container.read(assistantControllerProvider);
    expect(state.messages, isNotEmpty);
    expect(state.messages.first.role, 'user');
    expect(state.messages.first.text, 'where is the exit');
  });

  testWidgets('voice-unavailable surfaces a fallback hint', (tester) async {
    final container = ProviderContainer(
      overrides: [
        speechRecognizerProvider.overrideWithValue(
          _FakeSpeech()..available = false,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: AssistantHud()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = container.read(assistantControllerProvider.notifier);
    await notifier.startListening();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Voice input is not available'),
      findsOneWidget,
    );
  });
}