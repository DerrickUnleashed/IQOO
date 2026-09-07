// Widget tests for the onboarding experience.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/core/domain/models/app_session.dart';
import 'package:accesscopilot/features/onboarding/data/local_storage.dart';
import 'package:accesscopilot/features/onboarding/domain/onboarding_providers.dart';
import 'package:accesscopilot/features/onboarding/presentation/onboarding_pager.dart';

Widget _wrap(Widget child) {
  return ProviderScope(child: MaterialApp(home: child));
}

void main() {
  group('OnboardingPager', () {
    testWidgets('shows the three product pages in order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(OnboardingPager(onFinished: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Your AI accessibility copilot.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('See your environment.'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Personalized to you.'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('finishes when the last page is reached', (
      WidgetTester tester,
    ) async {
      var finished = false;
      await tester.pumpWidget(
        _wrap(OnboardingPager(onFinished: () => finished = true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });

    testWidgets('skip button finishes immediately', (
      WidgetTester tester,
    ) async {
      var finished = false;
      await tester.pumpWidget(
        _wrap(OnboardingPager(onFinished: () => finished = true)),
      );
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
    });
  });

  group('Onboarding providers', () {
    test('profile updates persist through the notifier', () async {
      final container = ProviderContainer(
        overrides: [localStorageProvider.overrideWithValue(_MemoryStorage())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(accessibilityProfileProvider.notifier);
      expect(
        container.read(accessibilityProfileProvider).mobility,
        MobilityAssistance.none,
      );

      notifier.update(
        const AccessibilityProfile(mobility: MobilityAssistance.wheelchair),
      );

      expect(
        container.read(accessibilityProfileProvider).mobility,
        MobilityAssistance.wheelchair,
      );
    });

    test('onboarding completed flag toggles', () async {
      final container = ProviderContainer(
        overrides: [localStorageProvider.overrideWithValue(_MemoryStorage())],
      );
      addTearDown(container.dispose);

      await container.read(onboardingCompletedProvider.notifier).complete();
      expect(container.read(onboardingCompletedProvider), isTrue);
    });
  });
}

class _MemoryStorage implements LocalStorage {
  bool _completed = false;
  AccessibilityProfile? _profile;
  AppSession? _session;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    _completed = completed;
  }

  @override
  Future<bool> isOnboardingCompleted() async => _completed;

  @override
  Future<void> saveProfile(AccessibilityProfile profile) async {
    _profile = profile;
  }

  @override
  Future<AccessibilityProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveSession(AppSession session) async {
    _session = session;
  }

  @override
  Future<AppSession?> loadSession() async => _session;
}
