// Tests for the routing controller (turn-by-turn state machine).

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesscopilot/core/api/api_client.g.dart' as api;
import 'package:accesscopilot/features/onboarding/domain/app_client_providers.dart';
import 'package:accesscopilot/features/routing/domain/route_controller.dart';

ProviderContainer makeContainer(MockClient mock) {
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api.ApiClient(httpClient: mock))],
  );
  addTearDown(container.dispose);
  return container;
}

final _routeJson = {
  'route_id': 'r-1',
  'distance_m': 42.0,
  'duration_estimate_s': 180,
  'accessibility_score': 0.9,
  'steps': [
    {'instruction': 'Exit the lobby', 'action_type': 'walk', 'distance_m': 12},
    {
      'instruction': 'Take the elevator to floor 2',
      'action_type': 'elevator',
      'required_accessibility': 'elevator',
    },
    {
      'instruction': 'Turn left at the corridor',
      'action_type': 'turn',
      'distance_m': 30,
    },
  ],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('startRoute loads an active route at step zero', () async {
    final container = makeContainer(
      MockClient((request) async => http.Response(jsonEncode(_routeJson), 200)),
    );

    final controller = container.read(routeControllerProvider.notifier);
    await controller.startRoute(
      origin: api.Location(latitude: 0, longitude: 0, floorLevel: 0),
      destination: api.Location(latitude: 0, longitude: 0, floorLevel: 1),
    );

    final state = container.read(routeControllerProvider);
    expect(state, isA<RouteActive>());
    final active = state as RouteActive;
    expect(active.route.steps, hasLength(3));
    expect(active.stepIndex, 0);
    expect(active.currentStep?.instruction, 'Exit the lobby');
  });

  test('step navigation moves forward and back within bounds', () async {
    final container = makeContainer(
      MockClient((request) async => http.Response(jsonEncode(_routeJson), 200)),
    );

    final controller = container.read(routeControllerProvider.notifier);
    await controller.startRoute(
      origin: api.Location(latitude: 0, longitude: 0),
      destination: api.Location(latitude: 0, longitude: 0, floorLevel: 2),
    );

    controller.nextStep();
    final second = container.read(routeControllerProvider) as RouteActive;
    expect(second.currentStep?.actionType, 'elevator');
    controller.nextStep();
    final third = container.read(routeControllerProvider) as RouteActive;
    expect(third.currentStep?.instruction, 'Turn left at the corridor');
    controller.nextStep(); // beyond end — stays
    final end = container.read(routeControllerProvider) as RouteActive;
    expect(end.stepIndex, 2);

    controller.previousStep();
    final prev = container.read(routeControllerProvider) as RouteActive;
    expect(prev.stepIndex, 1);
    controller.previousStep();
    controller.previousStep(); // before start — stays
    final start = container.read(routeControllerProvider) as RouteActive;
    expect(start.stepIndex, 0);
  });

  test('failed planner surfaces RouteFailed', () async {
    final container = makeContainer(
      MockClient((request) async => http.Response('gateway down', 503)),
    );

    final controller = container.read(routeControllerProvider.notifier);
    await controller.startRoute(
      origin: api.Location(latitude: 0, longitude: 0),
      destination: api.Location(latitude: 0, longitude: 0, floorLevel: 3),
    );

    expect(container.read(routeControllerProvider), isA<RouteFailed>());
  });

  test('reset returns to idle', () async {
    final container = makeContainer(
      MockClient((request) async => http.Response(jsonEncode(_routeJson), 200)),
    );
    final controller = container.read(routeControllerProvider.notifier);
    await controller.startRoute(
      origin: api.Location(latitude: 0, longitude: 0),
      destination: api.Location(latitude: 0, longitude: 0),
    );
    expect(container.read(routeControllerProvider), isA<RouteActive>());

    controller.reset();
    expect(container.read(routeControllerProvider), isA<RouteIdle>());
  });
}