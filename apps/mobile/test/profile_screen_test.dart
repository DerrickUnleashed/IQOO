// Widget tests for the personalized profile screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/core/domain/models/app_session.dart';
import 'package:accesscopilot/features/onboarding/data/local_storage.dart';
import 'package:accesscopilot/features/onboarding/domain/onboarding_providers.dart';
import 'package:accesscopilot/features/profile/presentation/profile_screen.dart';

void main() {
  group('ProfileScreen', () {
    testWidgets('shows profile sections and current selections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(_MemoryStorage()),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your guidance profile'), findsOneWidget);
      expect(find.text('Movement'), findsOneWidget);
      expect(find.text('Sight'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Guidance style'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Guidance style'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Privacy'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Walking speed'),
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Walking speed'), findsOneWidget);
    });

    testWidgets('updating movement selection persists via notifier', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(_MemoryStorage()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Select the Wheelchair chip in the Movement group.
      await tester.tap(find.text('Wheelchair'));
      await tester.pumpAndSettle();

      final profile = container.read(accessibilityProfileProvider);
      expect(profile.mobility, MobilityAssistance.wheelchair);
    });
  });
}

class _MemoryStorage implements LocalStorage {
  bool _completed = false;
  AccessibilityProfile? _profile;
  AppSession? _session;
  List<String> _queue = [];

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

  @override
  Future<void> saveEventQueue(List<String> events) async {
    _queue = events;
  }

  @override
  Future<List<String>> loadEventQueue() async => _queue;
}