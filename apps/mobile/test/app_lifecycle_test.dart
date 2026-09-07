// Tests for app lifecycle handling and router wiring.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/core/domain/models/app_session.dart';
import 'package:accesscopilot/core/lifecycle/app_lifecycle.dart';
import 'package:accesscopilot/core/domain/services/speech_synthesizer.dart';
import 'package:accesscopilot/core/router/app_router.dart';
import 'package:accesscopilot/features/onboarding/data/local_storage.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';

class _RecordingTts implements SpeechSynthesizer {
  bool available = true;
  final List<String> spoken = [];
  int stopCount = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCount++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLifecycleController', () {
    test('records lifecycle transitions and stops speech on background',
        () async {
      final tts = _RecordingTts();
      final container = ProviderContainer(
        overrides: [
          speechSynthesizerProvider.overrideWithValue(tts),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appLifecycleProvider.notifier);
      await controller.update(AppLifecycleState.resumed);
      expect(container.read(appLifecycleProvider), AppLifecycleState.resumed);
      expect(tts.stopCount, 0);

      await controller.update(AppLifecycleState.inactive);
      await controller.update(AppLifecycleState.paused);
      expect(container.read(appLifecycleProvider), AppLifecycleState.paused);
      expect(tts.stopCount, 1);

      await controller.update(AppLifecycleState.resumed);
      expect(tts.stopCount, 1);
    });
  });

  group('AppRouter', () {
    testWidgets('redirects to onboarding until it is completed', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(_InMemoryStorage()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Onboarding not completed: home redirects to onboarding.
      expect(
        router.state.uri.toString(),
        contains('/onboarding'),
      );
    });

    testWidgets('renders error page for unmatched routes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(_InMemoryStorage()..complete()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // Let onboarding hydration (async) finish before navigating.
      await tester.pumpAndSettle();

      router.go('/does/not/exist');
      await tester.pumpAndSettle();

      expect(find.text('This page does not exist.'), findsOneWidget);
      expect(find.text('Back home'), findsOneWidget);
    });

    testWidgets('home tiles navigate to assistance', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(_InMemoryStorage()..complete()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ask Copilot'));
      // The assistance screen runs an indeterminate camera spinner while the
      // camera provider initializes, which never "settles", so step instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.state.uri.toString(), contains('/assistance'));

      router.go(AppRoute.home);
      // The assistance screen keeps an indeterminate camera spinner alive
      // while its state settles, so step instead of settling forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Scan Environment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(router.state.uri.toString(), contains('/assistance'));
    });
  });
}

class _InMemoryStorage implements LocalStorage {
  bool _completed = false;

  @override
  Future<void> setOnboardingCompleted(bool completed) async =>
      _completed = completed;

  @override
  Future<bool> isOnboardingCompleted() async => _completed;

  @override
  Future<void> saveProfile(AccessibilityProfile profile) async {}

  @override
  Future<AccessibilityProfile?> loadProfile() async => null;

  @override
  Future<void> saveSession(AppSession session) async {}

  @override
  Future<AppSession?> loadSession() async => null;

  @override
  Future<void> saveEventQueue(List<String> events) async {}

  @override
  Future<List<String>> loadEventQueue() async => const [];

  @override
  Future<bool> isDemoModeEnabled() async => false;

  @override
  Future<void> setDemoModeEnabled(bool enabled) async {}

  _InMemoryStorage complete() {
    _completed = true;
    return this;
  }
}