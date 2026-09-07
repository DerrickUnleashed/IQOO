import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/core/domain/models/accessibility_profile.dart';
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';
import 'package:accesscopilot/features/onboarding/domain/onboarding_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeClient = api.ApiClient(
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body);
      if (request.url.path.endsWith('/auth/session')) {
        return http.Response(
          jsonEncode({
            'session_id': 'sess-test',
            'user_id': 1,
            'started_at': '2026-01-01T00:00:00Z',
            'status': 'active',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/users/me/profile')) {
        return http.Response(
          jsonEncode({
            'mobility': (body as Map?)?['mobility'],
            'vision': body?['vision'],
            'hearing': body?['hearing'],
            'guidance_style': body?['guidance_style'],
            'walking_speed_mps': body?['walking_speed_mps'],
            'max_comfortable_distance_m': body?['max_comfortable_distance_m'],
            'cognitive_load_preference': body?['cognitive_load_preference'],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    }),
  );

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(fakeClient)],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileNotifier (persistent, profile-aware state)', () {
    test('persists an update to local storage', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        accessibilityProfileProvider.notifier,
      );
      await notifier.update(
        const AccessibilityProfile(mobility: MobilityAssistance.wheelchair),
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('accessibility_profile');
      expect(stored, isNotNull);
      expect(stored, contains('wheelchair'));
      expect(stored, contains('"mobility"'));

      // State reflects the update immediately.
      expect(
        container.read(accessibilityProfileProvider).mobility,
        MobilityAssistance.wheelchair,
      );
    });

    test('hydrates a saved profile on first build', () async {
      SharedPreferences.setMockInitialValues({
        'accessibility_profile':
            '{"mobility":"cane","vision":"low_vision","hearing":"none",'
            '"guidance_style":"detailed","walking_speed_mps":1.0,'
            '"max_comfortable_distance_m":80,"cognitive_load_preference":2}',
      });

      final container = makeContainer();
      addTearDown(container.dispose);

      // First read triggers build() which schedules hydration.
      expect(container.read(accessibilityProfileProvider).mobility, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final profile = container.read(accessibilityProfileProvider);
      expect(profile.mobility, MobilityAssistance.cane);
      expect(profile.vision, VisionAssistance.lowVision);
      expect(profile.guidanceStyle, GuidanceStyle.detailed);
      expect(profile.walkingSpeedMps, 1.0);
    });

    test('profileGuidance follows the current profile', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        accessibilityProfileProvider.notifier,
      );

      expect(
        container.read(profileGuidanceProvider).preferStepFreePaths,
        isFalse,
      );
      await notifier.update(
        const AccessibilityProfile(mobility: MobilityAssistance.wheelchair),
      );
      expect(
        container.read(profileGuidanceProvider).preferStepFreePaths,
        isTrue,
      );
    });
  });
}